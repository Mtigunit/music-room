import {
  Injectable,
  NotFoundException,
  Inject,
  forwardRef,
} from '@nestjs/common';
import { UserRepository } from './user.repository';
import { type User } from '@prisma/client';
import { PaginationDto } from '../common/dto/pagination.dto';
import type { UpdateProfileDto } from './dto/update-profile.dto';
import { FollowsService } from '../follows/follows.service';

@Injectable()
export class UsersService {
  constructor(
    private readonly userRepository: UserRepository,
    @Inject(forwardRef(() => FollowsService))
    private readonly followsService: FollowsService,
  ) {}

  async findByEmail(email: string): Promise<User | null> {
    return this.userRepository.findByEmail(email);
  }

  async findByUsername(username: string): Promise<User | null> {
    return this.userRepository.findByUsername(username);
  }

  async findById(id: string): Promise<User | null> {
    return this.userRepository.findById(id);
  }

  async create(
    email: string,
    username: string,
    passwordHash: string,
    isEmailVerified?: boolean,
  ): Promise<User> {
    return this.userRepository.create({
      email,
      username,
      passwordHash,
      isEmailVerified,
    });
  }

  async findByGoogleId(googleId: string): Promise<User | null> {
    return this.userRepository.findByGoogleId(googleId);
  }

  async createOAuthUser(
    email: string,
    username: string,
    googleId: string,
    isEmailVerified: boolean = true,
  ): Promise<User> {
    return this.userRepository.createOAuthUser({
      email,
      username,
      googleId,
      isEmailVerified,
    });
  }

  async linkGoogleAccount(userId: string, googleId: string): Promise<User> {
    return this.userRepository.linkGoogleAccount(userId, googleId);
  }

  async updatePassword(userId: string, passwordHash: string): Promise<User> {
    return this.userRepository.updatePassword(userId, passwordHash);
  }

  async searchUsers(
    query: string,
    paginationDto: PaginationDto,
  ): Promise<{
    data: User[];
    meta: { total: number; page: number; limit: number };
  }> {
    return this.userRepository.searchUsers(query, paginationDto);
  }

  async updateProfile(userId: string, dto: UpdateProfileDto): Promise<User> {
    const user = await this.userRepository.updateProfile(userId, dto);
    if (!user) {
      throw new NotFoundException('User not found');
    }
    return user;
  }

  async updateAvatar(userId: string, avatarPath: string): Promise<User> {
    return this.userRepository.updateAvatar(userId, avatarPath);
  }

  async areUsersFriends(userId1: string, userId2: string): Promise<boolean> {
    const { isFriend } = await this.getRelationship(userId1, userId2);
    return isFriend;
  }

  async getRelationship(viewerId: string, targetId: string) {
    const [isFollowing, isFollowedBy] = await Promise.all([
      this.followsService.isFollowing(viewerId, targetId),
      this.followsService.isFollowing(targetId, viewerId),
    ]);
    return {
      isFollowing,
      isFollowedBy,
      isFriend: isFollowing && isFollowedBy,
    };
  }

  async isFollowing(followerId: string, followingId: string): Promise<boolean> {
    return this.followsService.isFollowing(followerId, followingId);
  }
}
