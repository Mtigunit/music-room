import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  ParseUUIDPipe,
  Query,
  Request,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  NotFoundException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiParam,
  ApiConsumes,
  ApiBody,
} from '@nestjs/swagger';
import { FileInterceptor } from '@nestjs/platform-express';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { SearchUsersDto } from './dto/search-users.dto';
import type { User } from '@prisma/client';
import type { UserProfileResponse } from './interfaces/user-profile-response.interface';

@ApiTags('Users')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('users')
export class UsersController {
  private readonly logger = new Logger(UsersController.name);

  constructor(private readonly usersService: UsersService) {}

  private toSafeUser(user: User): Omit<User, 'passwordHash' | 'googleId'> {
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const { passwordHash, googleId, ...safeUser } = user;
    return safeUser;
  }

  @Get('me')
  @ApiOperation({ summary: 'Get current user profile' })
  @ApiResponse({ status: 200, description: 'Current user profile.' })
  async getProfile(@Request() req: Express.Request) {
    // Guard validates the JWT signature only (stateless). This DB check catches the edge case
    // where the account was deleted after the token was issued but before it expired.
    const user = await this.usersService.findById(req.user!.id);
    if (!user) {
      throw new NotFoundException('User not found');
    }

    // We return everything except passwordHash and googleId
    return this.toSafeUser(user);
  }

  @Patch('me/profile')
  @ApiOperation({ summary: 'Update current user profile JSON fields' })
  @ApiResponse({ status: 200, description: 'Profile updated.' })
  async updateProfile(
    @Request() req: Express.Request,
    @Body() updateProfileDto: UpdateProfileDto,
  ) {
    const user = await this.usersService.updateProfile(
      req.user!.id,
      updateProfileDto,
    );
    return this.toSafeUser(user);
  }

  @Post('me/avatar')
  @UseInterceptors(FileInterceptor('avatar'))
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: 'Upload or replace the current user avatar' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        avatar: { type: 'string', format: 'binary' },
      },
    },
  })
  @ApiResponse({ status: 201, description: 'Avatar uploaded.' })
  @ApiResponse({
    status: 400,
    description: 'No file provided or invalid file type.',
  })
  async uploadAvatar(
    @Request() req: Express.Request,
    @UploadedFile() file?: Express.Multer.File,
  ) {
    if (!file) {
      throw new BadRequestException('An image file is required.');
    }

    // Get the current user to find their old avatar URL
    const oldUser = await this.usersService.findById(req.user!.id);
    const oldAvatarUrl = oldUser?.avatarUrl;

    let user;
    try {
      user = await this.usersService.updateAvatar(
        req.user!.id,
        `/uploads/${file.filename}`,
      );
    } catch (error) {
      // Clean up the newly uploaded file if the DB update fails
      try {
        await fs.promises.unlink(file.path);
      } catch {
        this.logger.error(
          `Failed to cleanup orphaned avatar file: ${file.path}`,
        );
      }
      throw error;
    }

    // If an old avatar exists and it's a local file, delete it
    if (oldAvatarUrl && oldAvatarUrl.startsWith('/uploads/')) {
      const filename = oldAvatarUrl.replace('/uploads/', '');
      const filePath = path.join(process.cwd(), 'uploads', filename);

      try {
        await fs.promises.unlink(filePath);
      } catch (error) {
        // Log the error but don't fail the request if cleanup fails
        this.logger.error(
          `Failed to delete old avatar file: ${filePath}`,
          error instanceof Error ? error.stack : undefined,
        );
      }
    }

    return this.toSafeUser(user);
  }

  @Get('search')
  @ApiOperation({ summary: 'Search users by username' })
  @ApiResponse({ status: 200, description: 'List of matching users.' })
  async searchUsers(@Query() searchDto: SearchUsersDto) {
    const { data, meta } = await this.usersService.searchUsers(
      searchDto.q,
      searchDto,
    );

    // Return only public information for search results
    const safeData = data.map((user: User) => ({
      id: user.id,
      username: user.username,
      avatarUrl: user.avatarUrl,
      publicInfo: user.publicInfo,
      subscriptionTier: user.subscriptionTier,
    }));

    return { data: safeData, meta };
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get a user by ID' })
  @ApiParam({ name: 'id', type: 'string', format: 'uuid' })
  @ApiResponse({
    status: 200,
    description: 'User profile according to visibility rules.',
  })
  @ApiResponse({ status: 404, description: 'User not found.' })
  async getUser(
    @Param('id', ParseUUIDPipe) id: string,
    @Request() req: Express.Request,
  ) {
    const user = await this.usersService.findById(id);
    if (!user) {
      throw new NotFoundException('User not found');
    }

    const isSelf = user.id === req.user!.id;
    const isFriend = isSelf
      ? false
      : await this.usersService.areUsersFriends(req.user!.id, user.id);

    // Visibility rules:
    // Everyone sees: id, username, avatarUrl, publicInfo, subscriptionTier
    // Friends see: + friendInfo
    // Self sees: + friendInfo, privateInfo, preferences, email

    const response: UserProfileResponse = {
      id: user.id,
      username: user.username,
      avatarUrl: user.avatarUrl,
      publicInfo: user.publicInfo,
      subscriptionTier: user.subscriptionTier,
    };

    if (isSelf || isFriend) {
      response.friendInfo = user.friendInfo;
    }

    if (isSelf) {
      response.privateInfo = user.privateInfo;
      response.preferences = user.preferences;
      response.email = user.email; // Email is private
    }

    return response;
  }
}
