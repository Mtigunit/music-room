import { Test, TestingModule } from '@nestjs/testing';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { NotFoundException, BadRequestException } from '@nestjs/common';
import type { User } from '@prisma/client';
import type { Request } from 'express';

const mockUser: User = {
  id: 'user-uuid-123',
  email: 'test@example.com',
  username: 'testuser',
  passwordHash: '$2b$10$hashedpassword',
  isEmailVerified: true,
  googleId: 'google-123',
  publicInfo: { shortBio: 'public bio' },
  friendInfo: { location: 'test#1234' },
  privateInfo: { physicalAddress: '123 street' },
  preferences: {},
  subscriptionTier: 'BASIC',
  avatarUrl: '/uploads/avatar.png',
  createdAt: new Date(),
  updatedAt: new Date(),
};

const mockSafeUser = {
  id: mockUser.id,
  email: mockUser.email,
  username: mockUser.username,
  isEmailVerified: mockUser.isEmailVerified,
  publicInfo: mockUser.publicInfo,
  friendInfo: mockUser.friendInfo,
  privateInfo: mockUser.privateInfo,
  preferences: mockUser.preferences,
  subscriptionTier: mockUser.subscriptionTier,
  avatarUrl: mockUser.avatarUrl,
  createdAt: mockUser.createdAt,
  updatedAt: mockUser.updatedAt,
};

describe('UsersController', () => {
  let controller: UsersController;
  let service: jest.Mocked<UsersService>;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [UsersController],
      providers: [
        {
          provide: UsersService,
          useValue: {
            findById: jest.fn(),
            updateProfile: jest.fn(),
            updateAvatar: jest.fn(),
            searchUsers: jest.fn(),
            areUsersFriends: jest.fn(),
          },
        },
      ],
    }).compile();

    controller = module.get<UsersController>(UsersController);
    service = module.get(UsersService);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  // ─── getProfile ───────────────────────────────────────

  describe('getProfile', () => {
    it('should return the current user profile without sensitive fields', async () => {
      service.findById.mockResolvedValue(mockUser);
      const req = { user: { id: mockUser.id } } as unknown as Request;

      const result = await controller.getProfile(req);

      expect(service.findById).toHaveBeenCalledWith(mockUser.id);
      expect(result).toEqual(mockSafeUser);
      expect(result).not.toHaveProperty('passwordHash');
      expect(result).not.toHaveProperty('googleId');
    });

    it('should throw NotFoundException if user is not found', async () => {
      service.findById.mockResolvedValue(null);
      const req = { user: { id: 'missing' } } as unknown as Request;

      await expect(controller.getProfile(req)).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  // ─── updateProfile ────────────────────────────────────

  describe('updateProfile', () => {
    it('should update the profile and return the safe user', async () => {
      const updatedUser = { ...mockUser, publicInfo: { bio: 'new bio' } };
      service.updateProfile.mockResolvedValue(updatedUser as any);

      const req = { user: { id: mockUser.id } } as unknown as Request;
      const dto = { publicInfo: { bio: 'new bio' } };

      const result = await controller.updateProfile(req, dto);

      expect(service.updateProfile).toHaveBeenCalledWith(mockUser.id, dto);
      expect(result.publicInfo).toEqual({ bio: 'new bio' });
      expect(result).not.toHaveProperty('passwordHash');
    });
  });

  // ─── uploadAvatar ─────────────────────────────────────

  describe('uploadAvatar', () => {
    it('should throw BadRequestException if no file is provided', async () => {
      const req = { user: { id: mockUser.id } } as unknown as Request;

      await expect(controller.uploadAvatar(req)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('should update avatar with relative url and return safe user', async () => {
      const file = {
        filename: 'new-avatar.png',
        path: '/tmp/new-avatar.png',
      } as Express.Multer.File;
      const updatedUser = { ...mockUser, avatarUrl: '/uploads/new-avatar.png' };
      service.findById.mockResolvedValue(mockUser as any);
      service.updateAvatar.mockResolvedValue(updatedUser as any);

      const req = { user: { id: mockUser.id } } as unknown as Request;

      const result = await controller.uploadAvatar(req, file);

      expect(service.updateAvatar).toHaveBeenCalledWith(
        mockUser.id,
        '/uploads/new-avatar.png',
      );
      expect(result.avatarUrl).toEqual('/uploads/new-avatar.png');
    });
  });

  // ─── searchUsers ──────────────────────────────────────

  describe('searchUsers', () => {
    it('should search users and return mapped public data', async () => {
      const dto = { q: 'test', page: 1, limit: 10 };
      const searchResult = {
        data: [mockUser],
        meta: { total: 1, page: 1, limit: 10 },
      };
      service.searchUsers.mockResolvedValue(searchResult);

      const result = await controller.searchUsers(dto);

      expect(service.searchUsers).toHaveBeenCalledWith('test', dto);
      expect(result.data).toHaveLength(1);
      expect(result.data[0]).toEqual({
        id: mockUser.id,
        username: mockUser.username,
        avatarUrl: mockUser.avatarUrl,
        publicInfo: mockUser.publicInfo,
        subscriptionTier: mockUser.subscriptionTier,
      });
      // Should not contain private data
      expect(result.data[0]).not.toHaveProperty('email');
      expect(result.data[0]).not.toHaveProperty('friendInfo');
      expect(result.meta).toEqual(searchResult.meta);
    });
  });

  // ─── getUser ──────────────────────────────────────────

  describe('getUser', () => {
    const req = { user: { id: 'viewer-uuid' } } as unknown as Request;

    it('should throw NotFoundException if user does not exist', async () => {
      service.findById.mockResolvedValue(null);
      await expect(controller.getUser('missing-uuid', req)).rejects.toThrow(
        NotFoundException,
      );
    });

    it('should return full private data when viewing self', async () => {
      service.findById.mockResolvedValue(mockUser);
      const selfReq = { user: { id: mockUser.id } } as unknown as Request;

      const result = await controller.getUser(mockUser.id, selfReq);

      expect(result).toEqual({
        id: mockUser.id,
        username: mockUser.username,
        avatarUrl: mockUser.avatarUrl,
        publicInfo: mockUser.publicInfo,
        subscriptionTier: mockUser.subscriptionTier,
        friendInfo: mockUser.friendInfo,
        privateInfo: mockUser.privateInfo,
        preferences: mockUser.preferences,
        email: mockUser.email,
      });
    });

    it('should return friend data when users are friends', async () => {
      service.findById.mockResolvedValue(mockUser);
      service.areUsersFriends.mockResolvedValue(true);

      const result = await controller.getUser(mockUser.id, req);

      expect(service.areUsersFriends).toHaveBeenCalledWith(
        'viewer-uuid',
        mockUser.id,
      );
      expect(result).toEqual({
        id: mockUser.id,
        username: mockUser.username,
        avatarUrl: mockUser.avatarUrl,
        publicInfo: mockUser.publicInfo,
        subscriptionTier: mockUser.subscriptionTier,
        friendInfo: mockUser.friendInfo,
      });
      expect(result).not.toHaveProperty('privateInfo');
      expect(result).not.toHaveProperty('email');
    });

    it('should return only public data when users are not friends', async () => {
      service.findById.mockResolvedValue(mockUser);
      service.areUsersFriends.mockResolvedValue(false);

      const result = await controller.getUser(mockUser.id, req);

      expect(result).toEqual({
        id: mockUser.id,
        username: mockUser.username,
        avatarUrl: mockUser.avatarUrl,
        publicInfo: mockUser.publicInfo,
        subscriptionTier: mockUser.subscriptionTier,
      });
      expect(result).not.toHaveProperty('friendInfo');
      expect(result).not.toHaveProperty('privateInfo');
    });
  });
});
