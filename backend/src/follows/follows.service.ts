import {
  Injectable,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { FollowsRepository } from './follows.repository';
import type { PaginationDto } from '../common/dto/pagination.dto';

@Injectable()
export class FollowsService {
  constructor(private readonly followsRepository: FollowsRepository) {}

  async followUser(followerId: string, followingId: string) {
    if (followerId === followingId) {
      throw new ConflictException('You cannot follow yourself');
    }

    const isAlreadyFollowing = await this.followsRepository.isFollowing(
      followerId,
      followingId,
    );
    if (isAlreadyFollowing) {
      throw new ConflictException('You are already following this user');
    }

    try {
      return await this.followsRepository.createFollow(followerId, followingId);
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError) {
        if (error.code === 'P2003') {
          throw new NotFoundException('User to follow not found');
        }
        if (error.code === 'P2002') {
          throw new ConflictException('You are already following this user');
        }
      }
      throw error;
    }
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
    return this.followsRepository.getFollowers(userId, paginationDto);
  }

  async getFollowing(userId: string, paginationDto: PaginationDto) {
    return this.followsRepository.getFollowing(userId, paginationDto);
  }

  async getFriends(userId: string, paginationDto: PaginationDto) {
    return this.followsRepository.getMutualFriends(userId, paginationDto);
  }

  async isFollowing(followerId: string, followingId: string): Promise<boolean> {
    return this.followsRepository.isFollowing(followerId, followingId);
  }
}
