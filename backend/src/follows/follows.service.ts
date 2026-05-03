import {
  Injectable,
  ConflictException,
  NotFoundException,
  Inject,
  forwardRef,
} from '@nestjs/common';
import { FollowsRepository } from './follows.repository';
import { UsersService } from '../users/users.service';
import type { PaginationDto } from '../common/dto/pagination.dto';

@Injectable()
export class FollowsService {
  constructor(
    private readonly followsRepository: FollowsRepository,
    @Inject(forwardRef(() => UsersService))
    private readonly usersService: UsersService,
  ) {}

  async followUser(followerId: string, followingId: string) {
    if (followerId === followingId) {
      throw new ConflictException('You cannot follow yourself');
    }

    const targetUser = await this.usersService.findById(followingId);
    if (!targetUser) {
      throw new NotFoundException('User to follow not found');
    }

    const isAlreadyFollowing = await this.followsRepository.isFollowing(
      followerId,
      followingId,
    );
    if (isAlreadyFollowing) {
      throw new ConflictException('You are already following this user');
    }

    return this.followsRepository.createFollow(followerId, followingId);
  }

  async unfollowUser(followerId: string, followingId: string) {
    const isFollowing = await this.followsRepository.isFollowing(
      followerId,
      followingId,
    );
    if (!isFollowing) {
      throw new NotFoundException('You are not following this user');
    }

    return this.followsRepository.deleteFollow(followerId, followingId);
  }

  async getFollowers(userId: string, paginationDto: PaginationDto) {
    const targetUser = await this.usersService.findById(userId);
    if (!targetUser) {
      throw new NotFoundException('User not found');
    }
    return this.followsRepository.getFollowers(userId, paginationDto);
  }

  async getFollowing(userId: string, paginationDto: PaginationDto) {
    const targetUser = await this.usersService.findById(userId);
    if (!targetUser) {
      throw new NotFoundException('User not found');
    }
    return this.followsRepository.getFollowing(userId, paginationDto);
  }

  async getFriends(userId: string, paginationDto: PaginationDto) {
    const targetUser = await this.usersService.findById(userId);
    if (!targetUser) {
      throw new NotFoundException('User not found');
    }
    return this.followsRepository.getMutualFriends(userId, paginationDto);
  }

  async isFollowing(followerId: string, followingId: string): Promise<boolean> {
    return this.followsRepository.isFollowing(followerId, followingId);
  }
}
