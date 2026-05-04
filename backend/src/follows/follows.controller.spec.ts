import { Test, TestingModule } from '@nestjs/testing';
import { FollowsController } from './follows.controller';
import { FollowsService } from './follows.service';
import type { Request } from 'express';
import type { User } from '@prisma/client';

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

describe('FollowsController', () => {
  let controller: FollowsController;
  let service: jest.Mocked<FollowsService>;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [FollowsController],
      providers: [
        {
          provide: FollowsService,
          useValue: {
            followUser: jest.fn(),
            unfollowUser: jest.fn(),
            getFollowers: jest.fn(),
            getFollowing: jest.fn(),
            getFriends: jest.fn(),
          },
        },
      ],
    }).compile();

    controller = module.get<FollowsController>(FollowsController);
    service = module.get(FollowsService);
  });

  const req = { user: { id: 'viewer' } } as unknown as Request;

  it('followUser', async () => {
    service.followUser.mockResolvedValue({
      followerId: 'viewer',
      followingId: 'target',
      createdAt: new Date(),
    });
    const res = await controller.followUser(req, 'target');
    expect(res).toEqual({ success: true });
    expect(service.followUser).toHaveBeenCalledWith('viewer', 'target');
  });

  it('unfollowUser', async () => {
    service.unfollowUser.mockResolvedValue({
      followerId: 'viewer',
      followingId: 'target',
      createdAt: new Date(),
    });
    const res = await controller.unfollowUser(req, 'target');
    expect(res).toEqual({ success: true });
    expect(service.unfollowUser).toHaveBeenCalledWith('viewer', 'target');
  });

  describe('getters', () => {
    const mockPagination = { page: 1, limit: 10 };
    const mockResult = {
      data: [mockUser],
      meta: { total: 1, page: 1, limit: 10 },
    };

    it('getFollowers', async () => {
      service.getFollowers.mockResolvedValue(mockResult);
      const res = await controller.getFollowers('target', mockPagination);
      expect(res.data[0]).toHaveProperty('username');
      expect(res.data[0]).not.toHaveProperty('passwordHash');
    });

    it('getFollowing', async () => {
      service.getFollowing.mockResolvedValue(mockResult);
      const res = await controller.getFollowing('target', mockPagination);
      expect(res.data[0]).toHaveProperty('username');
    });

    it('getFriends', async () => {
      service.getFriends.mockResolvedValue(mockResult);
      const res = await controller.getFriends('target', mockPagination);
      expect(res.data[0]).toHaveProperty('username');
    });
  });
});
