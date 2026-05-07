import { Test, TestingModule } from '@nestjs/testing';
import { FollowsService } from './follows.service';
import { FollowsRepository } from './follows.repository';
import { ConflictException, NotFoundException } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { NotificationType, Prisma } from '@prisma/client';
import type { User } from '@prisma/client';
import { NotificationPayloadType } from '../notifications/dto/notification-payload.dto';
import { NOTIFICATION_TRIGGER_EVENT } from '../notifications/notifications.constants';

const mockUser: User = {
  id: 'user-id',
  email: 'test@test.com',
  username: 'test',
  passwordHash: 'hash',
  isEmailVerified: true,
  googleId: null,
  publicInfo: null,
  friendInfo: null,
  privateInfo: null,
  preferences: null,
  subscriptionTier: 'BASIC',
  avatarUrl: null,
  createdAt: new Date(),
  updatedAt: new Date(),
};

describe('FollowsService', () => {
  let service: FollowsService;
  let repository: jest.Mocked<FollowsRepository>;
  let eventEmitter: jest.Mocked<EventEmitter2>;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        FollowsService,
        {
          provide: FollowsRepository,
          useValue: {
            createFollow: jest.fn(),
            deleteFollow: jest.fn(),
            isFollowing: jest.fn(),
            getFollowers: jest.fn(),
            getFollowing: jest.fn(),
            getMutualFriends: jest.fn(),
          },
        },
        {
          provide: EventEmitter2,
          useValue: {
            emit: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get<FollowsService>(FollowsService);
    repository = module.get(FollowsRepository);
    eventEmitter = module.get(EventEmitter2);
  });

  describe('followUser', () => {
    it('should successfully follow a user', async () => {
      repository.isFollowing.mockResolvedValue(false);
      repository.createFollow.mockResolvedValue({
        followerId: 'follower',
        followingId: 'following',
        createdAt: new Date(),
      });

      await service.followUser('follower', 'following');
      expect(repository.createFollow).toHaveBeenCalledWith(
        'follower',
        'following',
      );
      expect(eventEmitter.emit).toHaveBeenCalledWith(
        NOTIFICATION_TRIGGER_EVENT,
        expect.objectContaining({
          recipientId: 'following',
          type: NotificationType.FOLLOW,
          payload: {
            payloadType: NotificationPayloadType.USER,
            id: 'follower',
          },
        }),
      );
    });

    it('should throw ConflictException if following self', async () => {
      await expect(service.followUser('same', 'same')).rejects.toThrow(
        ConflictException,
      );
    });

    it('should throw NotFoundException if target user does not exist (handled by repository)', async () => {
      repository.isFollowing.mockResolvedValue(false);
      const prismaError = new Prisma.PrismaClientKnownRequestError(
        'Foreign key constraint failed',
        { code: 'P2003', clientVersion: '5.0.0' },
      );
      repository.createFollow.mockRejectedValue(prismaError);

      await expect(service.followUser('follower', 'missing')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('should throw ConflictException if already following (race condition handled by repository)', async () => {
      repository.isFollowing.mockResolvedValue(false);
      const prismaError = new Prisma.PrismaClientKnownRequestError(
        'Unique constraint failed',
        { code: 'P2002', clientVersion: '5.0.0' },
      );
      repository.createFollow.mockRejectedValue(prismaError);

      await expect(service.followUser('follower', 'following')).rejects.toThrow(
        ConflictException,
      );
    });

    it('should throw ConflictException if already following', async () => {
      repository.isFollowing.mockResolvedValue(true);
      await expect(service.followUser('follower', 'following')).rejects.toThrow(
        ConflictException,
      );
    });
  });

  describe('unfollowUser', () => {
    it('should successfully unfollow a user', async () => {
      repository.isFollowing.mockResolvedValue(true);
      repository.deleteFollow.mockResolvedValue({
        followerId: 'follower',
        followingId: 'following',
        createdAt: new Date(),
      });

      await service.unfollowUser('follower', 'following');
      expect(repository.deleteFollow).toHaveBeenCalledWith(
        'follower',
        'following',
      );
    });

    it('should throw NotFoundException if not following', async () => {
      repository.isFollowing.mockResolvedValue(false);
      await expect(
        service.unfollowUser('follower', 'following'),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('getters', () => {
    const mockPagination = { page: 1, limit: 10 };
    const mockResult = {
      data: [mockUser],
      meta: { total: 1, page: 1, limit: 10 },
    };

    it('getFollowers', async () => {
      repository.getFollowers.mockResolvedValue(mockResult);
      const res = await service.getFollowers('id', mockPagination);
      expect(res).toEqual(mockResult);
    });

    it('getFollowing', async () => {
      repository.getFollowing.mockResolvedValue(mockResult);
      const res = await service.getFollowing('id', mockPagination);
      expect(res).toEqual(mockResult);
    });

    it('getFriends', async () => {
      repository.getMutualFriends.mockResolvedValue(mockResult);
      const res = await service.getFriends('id', mockPagination);
      expect(res).toEqual(mockResult);
    });
  });
});
