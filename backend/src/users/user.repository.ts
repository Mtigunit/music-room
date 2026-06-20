import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { mergeJson } from '../common/utils/json-merge.util';
import { Prisma, SubscriptionTier, type User } from '@prisma/client';
import type { PaginationDto } from '../common/dto/pagination.dto';
import type { UpdateProfileDto } from './dto/update-profile.dto';

@Injectable()
export class UserRepository {
  constructor(private readonly prisma: PrismaService) {}

  async findByEmail(email: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { email } });
  }

  async findByUsername(username: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { username } });
  }

  async findById(id: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { id } });
  }

  async create(data: {
    email: string;
    username: string;
    passwordHash: string;
    isEmailVerified?: boolean;
  }): Promise<User> {
    return this.prisma.user.create({ data });
  }

  async findByGoogleId(googleId: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { googleId } });
  }

  async createOAuthUser(data: {
    email: string;
    username: string;
    googleId: string;
    isEmailVerified: boolean;
  }): Promise<User> {
    return this.prisma.user.create({ data });
  }

  async linkGoogleAccount(userId: string, googleId: string): Promise<User> {
    return this.prisma.user.update({
      where: { id: userId },
      data: { googleId, isEmailVerified: true },
    });
  }

  async unlinkGoogleAccount(userId: string): Promise<User> {
    return this.prisma.user.update({
      where: { id: userId },
      data: { googleId: null },
    });
  }

  async updatePassword(userId: string, passwordHash: string): Promise<User> {
    return this.prisma.user.update({
      where: { id: userId },
      data: { passwordHash },
    });
  }

  async searchUsers(
    query: string,
    paginationDto: PaginationDto,
  ): Promise<{
    data: User[];
    meta: { total: number; page: number; limit: number };
  }> {
    const { page = 1, limit = 20 } = paginationDto;
    const skip = (page - 1) * limit;

    const where: Prisma.UserWhereInput = {
      username: {
        contains: query,
        mode: 'insensitive',
      },
    };

    const [data, total] = await Promise.all([
      this.prisma.user.findMany({
        where,
        take: limit,
        skip,
        orderBy: { username: 'asc' },
      }),
      this.prisma.user.count({ where }),
    ]);

    return { data, meta: { total, page, limit } };
  }

  async updateProfile(
    userId: string,
    dto: UpdateProfileDto,
  ): Promise<User | null> {
    return this.prisma.$transaction(async (tx) => {
      const existing = await tx.user.findUnique({
        where: { id: userId },
      });
      if (!existing) return null;

      return tx.user.update({
        where: { id: userId },
        data: {
          ...(dto.publicInfo !== undefined && {
            publicInfo: mergeJson(
              existing.publicInfo,
              dto.publicInfo,
            ) as Prisma.InputJsonValue,
          }),
          ...(dto.friendInfo !== undefined && {
            friendInfo: mergeJson(
              existing.friendInfo,
              dto.friendInfo,
            ) as Prisma.InputJsonValue,
          }),
          ...(dto.privateInfo !== undefined && {
            privateInfo: mergeJson(
              existing.privateInfo,
              dto.privateInfo,
            ) as Prisma.InputJsonValue,
          }),
          ...(dto.preferences !== undefined && {
            preferences: mergeJson(
              existing.preferences,
              dto.preferences,
            ) as Prisma.InputJsonValue,
          }),
        },
      });
    });
  }

  async updateAvatar(userId: string, avatarPath: string): Promise<User> {
    return this.prisma.user.update({
      where: { id: userId },
      data: { avatarUrl: avatarPath },
    });
  }

  async updateEmail(userId: string, newEmail: string): Promise<User> {
    return this.prisma.user.update({
      where: { id: userId },
      data: { email: newEmail },
    });
  }

  async updateUsername(userId: string, newUsername: string): Promise<User> {
    return this.prisma.user.update({
      where: { id: userId },
      data: { username: newUsername },
    });
  }

  async incrementTokenVersion(userId: string): Promise<User> {
    return this.prisma.user.update({
      where: { id: userId },
      data: {
        tokenVersion: { increment: 1 },
      },
    });
  }

  async upgradeToPremium(userId: string): Promise<User | null> {
    try {
      return await this.prisma.user.update({
        where: {
          id: userId,
          subscriptionTier: SubscriptionTier.BASIC,
        },
        data: { subscriptionTier: SubscriptionTier.PREMIUM },
      });
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2025'
      ) {
        return null;
      }
      throw error;
    }
  }
}
