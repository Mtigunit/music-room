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
  Inject,
  forwardRef,
  Delete,
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
import { LinkGoogleDto } from './dto/link-google.dto';
import { AuthService } from '../auth/auth.service';
import { ClientMeta } from '../common/decorators/client-meta.decorator';
import { RequestEmailUpdateDto } from './dto/request-email-update.dto';
import { VerifyEmailUpdateDto } from './dto/verify-email-update.dto';
import { ApiClientMeta } from '../common/decorators/api-client-meta.decorator';
import { ClientMetaDto } from '../common/dto/client-meta.dto';
import type { User } from '@prisma/client';
import type { UserProfileResponse } from './interfaces/user-profile-response.interface';

@ApiTags('Users')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('users')
export class UsersController {
  private readonly logger = new Logger(UsersController.name);

  constructor(
    private readonly usersService: UsersService,
    @Inject(forwardRef(() => AuthService))
    private readonly authService: AuthService,
  ) {}

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

  @Post('link-google')
  @ApiClientMeta()
  @ApiOperation({ summary: 'Manually link a Google account' })
  @ApiResponse({
    status: 200,
    description: 'Google account linked successfully.',
  })
  @ApiResponse({
    status: 409,
    description: 'Google ID is already linked to another account.',
  })
  async linkGoogleAccount(
    @Request() req: Express.Request,
    @Body() dto: LinkGoogleDto,
    @ClientMeta() meta: ClientMetaDto,
  ) {
    const { sub: googleId } = await this.authService.verifyGoogleIdToken(
      dto.idToken,
    );

    const updatedUser = await this.usersService.linkGoogleAccount(
      req.user!.id,
      googleId,
      meta,
    );
    return this.toSafeUser(updatedUser);
  }

  @Delete('link-google')
  @ApiClientMeta()
  @ApiOperation({ summary: 'Manually unlink a Google account' })
  @ApiResponse({
    status: 200,
    description: 'Google account unlinked successfully.',
  })
  @ApiResponse({
    status: 400,
    description: 'Cannot unlink without a password set.',
  })
  @ApiResponse({
    status: 404,
    description: 'User not found.',
  })
  async unlinkGoogleAccount(
    @Request() req: Express.Request,
    @ClientMeta() meta: ClientMetaDto,
  ) {
    const updatedUser = await this.usersService.unlinkGoogleAccount(
      req.user!.id,
      meta,
    );
    return this.toSafeUser(updatedUser);
  }

  @Post('me/email/request')
  @ApiClientMeta()
  @ApiOperation({ summary: 'Request an email update (Phase 1)' })
  @ApiResponse({ status: 201, description: 'OTP sent to new email.' })
  @ApiResponse({ status: 401, description: 'Invalid current password.' })
  @ApiResponse({
    status: 409,
    description: 'New email address already in use.',
  })
  async requestEmailUpdate(
    @Request() req: Express.Request,
    @Body() dto: RequestEmailUpdateDto,
    @ClientMeta() meta: ClientMetaDto,
  ) {
    await this.usersService.requestEmailUpdate(req.user!.id, dto, meta);
    return {
      message:
        'OTP sent to your new email. Please verify it to complete the update.',
    };
  }

  @Post('me/email/verify')
  @ApiClientMeta()
  @ApiOperation({ summary: 'Verify email update OTP (Phase 2)' })
  @ApiResponse({ status: 200, description: 'Email updated successfully.' })
  @ApiResponse({ status: 400, description: 'Invalid or expired OTP.' })
  async verifyEmailUpdate(
    @Request() req: Express.Request,
    @Body() dto: VerifyEmailUpdateDto,
    @ClientMeta() meta: ClientMetaDto,
  ) {
    const user = await this.usersService.verifyEmailUpdate(
      req.user!.id,
      dto.code,
      meta,
    );
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
    let isFollowing = false;
    let isFollowedBy = false;
    let isFriend = false;

    if (!isSelf) {
      ({ isFollowing, isFollowedBy, isFriend } =
        await this.usersService.getRelationship(req.user!.id, user.id));
    }

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
    } else {
      response.isFollowing = isFollowing;
      response.isFollowedBy = isFollowedBy;
      response.isFriend = isFriend;
    }

    return response;
  }
}
