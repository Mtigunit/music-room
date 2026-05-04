import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import type { Follows, User } from '@prisma/client';
import type { PaginationDto } from '../common/dto/pagination.dto';

@Injectable()
export class FollowsRepository {
  constructor(private readonly prisma: PrismaService) {}

  async createFollow(
    followerId: string,
    followingId: string,
  ): Promise<Follows> {
    return this.prisma.follows.create({
      data: { followerId, followingId },
    });
  }

  async deleteFollow(
    followerId: string,
    followingId: string,
  ): Promise<Follows> {
    return this.prisma.follows.delete({
      where: {
        followerId_followingId: { followerId, followingId },
      },
    });
  }

  async isFollowing(followerId: string, followingId: string): Promise<boolean> {
    const follow = await this.prisma.follows.findUnique({
      where: {
        followerId_followingId: { followerId, followingId },
      },
    });
    return !!follow;
  }

  async getFollowers(
    userId: string,
    paginationDto: PaginationDto,
  ): Promise<{
    data: User[];
    meta: { total: number; page: number; limit: number };
  }> {
    const { page = 1, limit = 20 } = paginationDto;
    const skip = (page - 1) * limit;

    const [follows, total] = await Promise.all([
      this.prisma.follows.findMany({
        where: { followingId: userId },
        include: { follower: true },
        take: limit,
        skip,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.follows.count({ where: { followingId: userId } }),
    ]);

    const data = follows.map((f) => f.follower);
    return { data, meta: { total, page, limit } };
  }

  async getFollowing(
    userId: string,
    paginationDto: PaginationDto,
  ): Promise<{
    data: User[];
    meta: { total: number; page: number; limit: number };
  }> {
    const { page = 1, limit = 20 } = paginationDto;
    const skip = (page - 1) * limit;

    const [follows, total] = await Promise.all([
      this.prisma.follows.findMany({
        where: { followerId: userId },
        include: { following: true },
        take: limit,
        skip,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.follows.count({ where: { followerId: userId } }),
    ]);

    const data = follows.map((f) => f.following);
    return { data, meta: { total, page, limit } };
  }

  async getMutualFriends(
    userId: string,
    paginationDto: PaginationDto,
  ): Promise<{
    data: User[];
    meta: { total: number; page: number; limit: number };
  }> {
    const { page = 1, limit = 20 } = paginationDto;
    const skip = (page - 1) * limit;

    const [data, total] = await Promise.all([
      this.prisma.user.findMany({
        where: {
          AND: [
            { followers: { some: { followerId: userId } } },
            { following: { some: { followingId: userId } } },
          ],
        },
        take: limit,
        skip,
        orderBy: { username: 'asc' },
      }),
      this.prisma.user.count({
        where: {
          AND: [
            { followers: { some: { followerId: userId } } },
            { following: { some: { followingId: userId } } },
          ],
        },
      }),
    ]);

    return { data, meta: { total, page, limit } };
  }
}
