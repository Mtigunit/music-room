import {
  Controller,
  Post,
  Delete,
  Get,
  Param,
  Query,
  Request,
  UseGuards,
  ParseUUIDPipe,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiParam,
} from '@nestjs/swagger';
import { FollowsService } from './follows.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { PaginationDto } from '../common/dto/pagination.dto';
import type { User } from '@prisma/client';

@ApiTags('Follows')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('users')
export class FollowsController {
  constructor(private readonly followsService: FollowsService) {}

  private mapSafeUsers(data: User[]) {
    return data.map((user) => ({
      id: user.id,
      username: user.username,
      avatarUrl: user.avatarUrl,
      publicInfo: user.publicInfo,
      subscriptionTier: user.subscriptionTier,
    }));
  }

  @Post(':id/follow')
  @ApiOperation({ summary: 'Follow a user' })
  @ApiParam({ name: 'id', type: 'string', format: 'uuid' })
  @ApiResponse({ status: 201, description: 'Successfully followed the user.' })
  @ApiResponse({ status: 404, description: 'User not found.' })
  @ApiResponse({
    status: 409,
    description: 'Already following or trying to follow self.',
  })
  async followUser(
    @Request() req: Express.Request,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    await this.followsService.followUser(req.user!.id, id);
    return { success: true };
  }

  @Delete(':id/follow')
  @ApiOperation({ summary: 'Unfollow a user' })
  @ApiParam({ name: 'id', type: 'string', format: 'uuid' })
  @ApiResponse({
    status: 200,
    description: 'Successfully unfollowed the user.',
  })
  @ApiResponse({ status: 404, description: 'User not found or not following.' })
  async unfollowUser(
    @Request() req: Express.Request,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    await this.followsService.unfollowUser(req.user!.id, id);
    return { success: true };
  }

  @Get(':id/followers')
  @ApiOperation({ summary: 'Get a list of users following the target user' })
  @ApiParam({ name: 'id', type: 'string', format: 'uuid' })
  @ApiResponse({ status: 200, description: 'List of followers.' })
  async getFollowers(
    @Param('id', ParseUUIDPipe) id: string,
    @Query() paginationDto: PaginationDto,
  ) {
    const { data, meta } = await this.followsService.getFollowers(
      id,
      paginationDto,
    );
    return { data: this.mapSafeUsers(data), meta };
  }

  @Get(':id/following')
  @ApiOperation({ summary: 'Get a list of users the target user is following' })
  @ApiParam({ name: 'id', type: 'string', format: 'uuid' })
  @ApiResponse({ status: 200, description: 'List of following.' })
  async getFollowing(
    @Param('id', ParseUUIDPipe) id: string,
    @Query() paginationDto: PaginationDto,
  ) {
    const { data, meta } = await this.followsService.getFollowing(
      id,
      paginationDto,
    );
    return { data: this.mapSafeUsers(data), meta };
  }

  @Get(':id/friends')
  @ApiOperation({
    summary: 'Get a list of mutual friends (bidirectional follows)',
  })
  @ApiParam({ name: 'id', type: 'string', format: 'uuid' })
  @ApiResponse({ status: 200, description: 'List of mutual friends.' })
  async getFriends(
    @Param('id', ParseUUIDPipe) id: string,
    @Query() paginationDto: PaginationDto,
  ) {
    const { data, meta } = await this.followsService.getFriends(
      id,
      paginationDto,
    );
    return { data: this.mapSafeUsers(data), meta };
  }
}
