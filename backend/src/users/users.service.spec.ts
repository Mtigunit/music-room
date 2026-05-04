import { Test, TestingModule } from '@nestjs/testing';
import { UsersService } from './users.service';
import { UserRepository } from './user.repository';
import { FollowsService } from '../follows/follows.service';
import type { User } from '@prisma/client';

const mockUser: User = {
  id: 'user-uuid-123',
  email: 'test@example.com',
  username: 'testuser',
  passwordHash: '$2b$10$hashedpassword',
  isEmailVerified: false,
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

describe('UsersService', () => {
  let service: UsersService;
  let repository: jest.Mocked<UserRepository>;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        {
          provide: UserRepository,
          useValue: {
            findByEmail: jest.fn(),
            findByUsername: jest.fn(),
            findById: jest.fn(),
            findByGoogleId: jest.fn(),
            create: jest.fn(),
            createOAuthUser: jest.fn(),
            linkGoogleAccount: jest.fn(),
            updatePassword: jest.fn(),
          },
        },
        {
          provide: FollowsService,
          useValue: {
            isFollowing: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get<UsersService>(UsersService);
    repository = module.get(UserRepository);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  // ─── findByEmail ──────────────────────────────────────

  describe('findByEmail', () => {
    it('should return a user when found', async () => {
      repository.findByEmail.mockResolvedValue(mockUser);

      const result = await service.findByEmail('test@example.com');

      expect(result).toEqual(mockUser);
      expect(repository.findByEmail).toHaveBeenCalledWith('test@example.com');
    });

    it('should return null when user not found', async () => {
      repository.findByEmail.mockResolvedValue(null);

      const result = await service.findByEmail('nonexistent@example.com');

      expect(result).toBeNull();
    });
  });

  // ─── findByUsername ───────────────────────────────────

  describe('findByUsername', () => {
    it('should return a user when found', async () => {
      repository.findByUsername.mockResolvedValue(mockUser);

      const result = await service.findByUsername('testuser');

      expect(result).toEqual(mockUser);
      expect(repository.findByUsername).toHaveBeenCalledWith('testuser');
    });

    it('should return null when user not found', async () => {
      repository.findByUsername.mockResolvedValue(null);

      const result = await service.findByUsername('ghost');

      expect(result).toBeNull();
    });
  });

  // ─── findById ─────────────────────────────────────────

  describe('findById', () => {
    it('should return a user when found', async () => {
      repository.findById.mockResolvedValue(mockUser);

      const result = await service.findById('user-uuid-123');

      expect(result).toEqual(mockUser);
      expect(repository.findById).toHaveBeenCalledWith('user-uuid-123');
    });

    it('should return null when user not found', async () => {
      repository.findById.mockResolvedValue(null);

      const result = await service.findById('nonexistent-uuid');

      expect(result).toBeNull();
    });
  });

  // ─── create ───────────────────────────────────────────

  describe('create', () => {
    it('should delegate to repository with correct arguments', async () => {
      repository.create.mockResolvedValue(mockUser);

      const result = await service.create(
        'test@example.com',
        'testuser',
        '$2b$10$hashed',
        true,
      );

      expect(result).toEqual(mockUser);
      expect(repository.create).toHaveBeenCalledWith({
        email: 'test@example.com',
        username: 'testuser',
        passwordHash: '$2b$10$hashed',
        isEmailVerified: true,
      });
    });
  });
  // ─── findByGoogleId ───────────────────────────────────

  describe('findByGoogleId', () => {
    it('should return a user when found by google ID', async () => {
      repository.findByGoogleId.mockResolvedValue(mockUser);

      const result = await service.findByGoogleId('google-sub-123');

      expect(result).toEqual(mockUser);
      expect(repository.findByGoogleId).toHaveBeenCalledWith('google-sub-123');
    });

    it('should return null when user not found by google ID', async () => {
      repository.findByGoogleId.mockResolvedValue(null);

      const result = await service.findByGoogleId('missing-google-id');

      expect(result).toBeNull();
    });
  });

  // ─── createOAuthUser ──────────────────────────────────

  describe('createOAuthUser', () => {
    it('should delegate to repository to create OAuth user with verified email', async () => {
      repository.createOAuthUser.mockResolvedValue(mockUser);

      const result = await service.createOAuthUser(
        'google@example.com',
        'googleuser',
        'google-sub-123',
        true,
      );

      expect(result).toEqual(mockUser);
      expect(result).toEqual(mockUser);
      expect(repository.createOAuthUser).toHaveBeenCalledWith({
        email: 'google@example.com',
        username: 'googleuser',
        googleId: 'google-sub-123',
        isEmailVerified: true,
      });
    });
  });

  // ─── linkGoogleAccount ────────────────────────────────

  describe('linkGoogleAccount', () => {
    it('should delegate to repository to link Google account', async () => {
      repository.linkGoogleAccount.mockResolvedValue(mockUser);

      const result = await service.linkGoogleAccount(
        'user-uuid-123',
        'google-sub-123',
      );

      expect(result).toEqual(mockUser);
      expect(repository.linkGoogleAccount).toHaveBeenCalledWith(
        'user-uuid-123',
        'google-sub-123',
      );
    });
  });

  // ─── updatePassword ───────────────────────────────────

  describe('updatePassword', () => {
    it('should delegate to repository to update password', async () => {
      repository.updatePassword.mockResolvedValue(mockUser);

      const result = await service.updatePassword(
        'user-uuid-123',
        '$new$hashed$password',
      );

      expect(result).toEqual(mockUser);
      expect(repository.updatePassword).toHaveBeenCalledWith(
        'user-uuid-123',
        '$new$hashed$password',
      );
    });
  });
});
