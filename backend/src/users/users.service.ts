import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { UserRepository } from './user.repository';
import { Prisma, type User } from '@prisma/client';
import { PaginationDto } from '../common/dto/pagination.dto';
import type { UpdateProfileDto } from './dto/update-profile.dto';
import { FollowsService } from '../follows/follows.service';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { AUDIT_LOG_EVENT, AuditAction } from '../audit-log/audit-log.constants';
import { createAuditLogEvent } from '../audit-log/audit-log.event';
import { OtpService, OtpData } from '../otp/otp.service';
import { MailService } from '../mail/mail.service';
import { RequestEmailUpdateDto } from './dto/request-email-update.dto';
import { ClientMetaDto } from '../common/dto/client-meta.dto';
import { UpdateUsernameDto } from './dto/update-username.dto';

@Injectable()
export class UsersService {
  private readonly logger = new Logger(UsersService.name);

  constructor(
    private readonly userRepository: UserRepository,
    private readonly followsService: FollowsService,
    private readonly otpService: OtpService,
    private readonly mailService: MailService,
    private readonly eventEmitter: EventEmitter2,
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

  async linkGoogleAccount(
    userId: string,
    googleId: string,
    meta?: ClientMetaDto,
  ): Promise<User> {
    const existing = await this.userRepository.findByGoogleId(googleId);
    if (existing && existing.id !== userId) {
      throw new ConflictException(
        'This Google account is already linked to another profile',
      );
    }

    const user = await this.userRepository.linkGoogleAccount(userId, googleId);

    if (meta) {
      this.eventEmitter.emit(
        AUDIT_LOG_EVENT,
        createAuditLogEvent(userId, AuditAction.LINK_GOOGLE, meta, {
          googleId,
        }),
      );
    }

    return user;
  }

  async unlinkGoogleAccount(
    userId: string,
    meta?: ClientMetaDto,
  ): Promise<User> {
    const user = await this.userRepository.findById(userId);
    if (!user) {
      throw new NotFoundException('User not found');
    }
    if (!user.passwordHash) {
      throw new BadRequestException(
        'Cannot unlink Google account without setting a password first',
      );
    }

    const updatedUser = await this.userRepository.unlinkGoogleAccount(userId);

    if (meta) {
      this.eventEmitter.emit(
        AUDIT_LOG_EVENT,
        createAuditLogEvent(userId, AuditAction.UNLINK_GOOGLE, meta, {
          previousGoogleId: user.googleId,
        }),
      );
    }

    return updatedUser;
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

  async requestEmailUpdate(
    userId: string,
    dto: RequestEmailUpdateDto,
    meta: ClientMetaDto,
  ): Promise<void> {
    const user = await this.userRepository.findById(userId);
    if (!user) {
      throw new NotFoundException('User not found');
    }

    if (!user.passwordHash) {
      throw new BadRequestException(
        'A password is required to change your email address',
      );
    }

    // 1. Verify password
    const isPasswordValid = await bcrypt.compare(
      dto.password,
      user.passwordHash,
    );
    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid current password');
    }

    if (dto.newEmail === user.email) {
      throw new BadRequestException('New email is the same as the current one');
    }

    // 2. Check if new email is already in use
    const existing = await this.userRepository.findByEmail(dto.newEmail);
    if (existing) {
      throw new ConflictException('New email address is already in use');
    }

    // 3. Send OTP to new email and Alert to old email
    await this.otpService.sendOtp(userId, 'email_update', dto.newEmail, {
      newEmail: dto.newEmail,
    });
    await this.mailService.sendSecurityAlert(user.email, dto.newEmail);

    this.logger.log(
      `Email update requested for user ${userId} to ${dto.newEmail}`,
    );

    this.eventEmitter.emit(
      AUDIT_LOG_EVENT,
      createAuditLogEvent(userId, AuditAction.UPDATE_PROFILE, meta, {
        type: 'email_update_request',
        newEmail: dto.newEmail,
      }),
    );
  }

  async verifyEmailUpdate(
    userId: string,
    code: string,
    meta: ClientMetaDto,
  ): Promise<User> {
    const { data }: { data?: OtpData } = await this.otpService.verifyOtp(
      userId,
      code,
      'email_update',
    );

    const newEmail = data?.newEmail;

    if (!newEmail) {
      throw new BadRequestException('Invalid email update request state');
    }

    // 2. Perform DB update
    let updatedUser: User;
    try {
      updatedUser = await this.userRepository.updateEmail(userId, newEmail);
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw new ConflictException('New email address is already in use');
      }
      throw error;
    }

    this.logger.log(`Email updated for user ${userId} to ${newEmail}`);

    this.eventEmitter.emit(
      AUDIT_LOG_EVENT,
      createAuditLogEvent(userId, AuditAction.UPDATE_PROFILE, meta, {
        type: 'email_update_verify',
        newEmail,
      }),
    );

    return updatedUser;
  }

  async updateUsername(
    userId: string,
    dto: UpdateUsernameDto,
    meta: ClientMetaDto,
  ): Promise<User> {
    const user = await this.userRepository.findById(userId);
    if (!user) {
      throw new NotFoundException('User not found');
    }

    if (dto.username === user.username) {
      throw new BadRequestException(
        'New username is the same as the current one',
      );
    }

    try {
      const updatedUser = await this.userRepository.updateUsername(
        userId,
        dto.username,
      );

      this.eventEmitter.emit(
        AUDIT_LOG_EVENT,
        createAuditLogEvent(userId, AuditAction.UPDATE_USERNAME, meta, {
          oldUsername: user.username,
          newUsername: dto.username,
        }),
      );

      return updatedUser;
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw new ConflictException('Username is already taken');
      }
      throw error;
    }
  }

  async incrementTokenVersion(userId: string): Promise<User> {
    return this.userRepository.incrementTokenVersion(userId);
  }
}
