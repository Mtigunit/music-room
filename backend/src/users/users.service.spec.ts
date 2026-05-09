import { Test, TestingModule } from '@nestjs/testing';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { ConflictException, BadRequestException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { UsersService } from './users.service';
import { UserRepository } from './user.repository';
import { FollowsService } from '../follows/follows.service';
import { OtpService } from '../otp/otp.service';
import { MailService } from '../mail/mail.service';
import type { User } from '@prisma/client';

jest.mock('bcrypt');

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
  tokenVersion: 0,
  createdAt: new Date(),
  updatedAt: new Date(),
};

const mockMeta = {
  platform: 'ios',
  deviceModel: 'iPhone 13',
  appVersion: '1.0.0',
  ipAddress: '127.0.0.1',
};

describe('UsersService', () => {
  let service: UsersService;
  let repository: jest.Mocked<UserRepository>;
  let otpService: jest.Mocked<OtpService>;
  let mailService: jest.Mocked<MailService>;
  let eventEmitter: jest.Mocked<EventEmitter2>;

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
            unlinkGoogleAccount: jest.fn(),
            updatePassword: jest.fn(),
            updateEmail: jest.fn(),
            updateEmailAndIncrementToken: jest.fn(),
            incrementTokenVersion: jest.fn(),
            updateAvatar: jest.fn(),
          },
        },
        {
          provide: FollowsService,
          useValue: {
            isFollowing: jest.fn(),
          },
        },
        {
          provide: OtpService,
          useValue: {
            sendOtp: jest.fn(),
            verifyOtp: jest.fn(),
          },
        },
        {
          provide: MailService,
          useValue: {
            sendSecurityAlert: jest.fn(),
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

    service = module.get<UsersService>(UsersService);
    repository = module.get(UserRepository);
    otpService = module.get(OtpService);
    mailService = module.get(MailService);
    eventEmitter = module.get(EventEmitter2);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('findByEmail', () => {
    it('should return a user when found', async () => {
      repository.findByEmail.mockResolvedValue(mockUser);
      const result = await service.findByEmail('test@example.com');
      expect(result).toEqual(mockUser);
    });
  });

  describe('findById', () => {
    it('should return a user when found', async () => {
      repository.findById.mockResolvedValue(mockUser);
      const result = await service.findById('user-uuid-123');
      expect(result).toEqual(mockUser);
    });
  });

  describe('linkGoogleAccount', () => {
    it('should link account if not already linked', async () => {
      repository.findByGoogleId.mockResolvedValue(null);
      repository.linkGoogleAccount.mockResolvedValue(mockUser);

      await service.linkGoogleAccount('user-id', 'google-id', mockMeta);

      expect(repository.linkGoogleAccount).toHaveBeenCalledWith(
        'user-id',
        'google-id',
      );
      expect(eventEmitter.emit).toHaveBeenCalled();
    });

    it('should throw ConflictException if Google ID is already linked', async () => {
      repository.findByGoogleId.mockResolvedValue({ id: 'other-user' } as User);
      await expect(
        service.linkGoogleAccount('user-id', 'google-id'),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('unlinkGoogleAccount', () => {
    it('should unlink if password is set', async () => {
      repository.findById.mockResolvedValue(mockUser);
      repository.unlinkGoogleAccount.mockResolvedValue(mockUser);

      await service.unlinkGoogleAccount(mockUser.id, mockMeta);

      expect(repository.unlinkGoogleAccount).toHaveBeenCalledWith(mockUser.id);
    });

    it('should throw BadRequestException if no password set', async () => {
      repository.findById.mockResolvedValue({
        ...mockUser,
        passwordHash: null,
      });
      await expect(service.unlinkGoogleAccount(mockUser.id)).rejects.toThrow(
        BadRequestException,
      );
    });
  });

  describe('requestEmailUpdate', () => {
    const dto = { newEmail: 'new@email.com', password: 'password123' };

    it('should send OTP and alert on valid request', async () => {
      repository.findById.mockResolvedValue(mockUser);
      (bcrypt.compare as jest.Mock).mockResolvedValue(true);
      repository.findByEmail.mockResolvedValue(null);

      await service.requestEmailUpdate(mockUser.id, dto, mockMeta);

      expect(otpService.sendOtp).toHaveBeenCalled();
      expect(mailService.sendSecurityAlert).toHaveBeenCalled();
    });
  });

  describe('verifyEmailUpdate', () => {
    it('should update email on valid code', async () => {
      otpService.verifyOtp.mockResolvedValue({
        token: 'v-token',
        data: { newEmail: 'new@email.com' },
      });
      repository.updateEmail.mockResolvedValue({
        ...mockUser,
        email: 'new@email.com',
      });

      const result = await service.verifyEmailUpdate(
        mockUser.id,
        '123456',
        mockMeta,
      );

      expect(result.email).toBe('new@email.com');
      expect(repository.updateEmail).toHaveBeenCalledWith(
        mockUser.id,
        'new@email.com',
      );
    });
  });
});
