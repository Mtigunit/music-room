import { Test, TestingModule } from '@nestjs/testing';
import { EventEmitter2 } from '@nestjs/event-emitter';
import {
  ConflictException,
  BadRequestException,
  UnauthorizedException,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { UsersService } from './users.service';
import { UserRepository } from './user.repository';
import { FollowsService } from '../follows/follows.service';
import { OtpService } from '../otp/otp.service';
import { MailService } from '../mail/mail.service';
import { Prisma, SubscriptionTier, type User } from '@prisma/client';
import { AUDIT_LOG_EVENT } from '../audit-log/audit-log.constants';

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
  deviceId: 'unknown',
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
            updateUsername: jest.fn(),
            updateEmailAndIncrementToken: jest.fn(),
            incrementTokenVersion: jest.fn(),
            updateAvatar: jest.fn(),
            upgradeToPremium: jest.fn(),
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

    it('should throw BadRequestException if new email same as current', async () => {
      repository.findById.mockResolvedValue(mockUser);
      const sameEmailDto = {
        newEmail: mockUser.email,
        password: 'password123',
      };
      await expect(
        service.requestEmailUpdate(mockUser.id, sameEmailDto, mockMeta),
      ).rejects.toThrow('New email is the same as the current one');
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

    it('should throw ConflictException on database unique constraint error', async () => {
      otpService.verifyOtp.mockResolvedValue({
        token: 'v-token',
        data: { newEmail: 'new@email.com' },
      });
      repository.findByEmail.mockResolvedValue(null); // No collision in check

      const prismaError = new Prisma.PrismaClientKnownRequestError(
        'Unique constraint failed on the fields: (`email`)',
        {
          code: 'P2002',
          clientVersion: '5.0.0',
        },
      );
      repository.updateEmail.mockRejectedValue(prismaError);

      await expect(
        service.verifyEmailUpdate(mockUser.id, '123456', mockMeta),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('updateUsername', () => {
    const dto = { username: 'new_username' };

    it('should update username successfully', async () => {
      repository.findById.mockResolvedValue(mockUser);
      repository.updateUsername.mockResolvedValue({
        ...mockUser,
        username: dto.username,
      });

      const result = await service.updateUsername(mockUser.id, dto, mockMeta);

      expect(result.username).toBe(dto.username);
      expect(repository.updateUsername).toHaveBeenCalledWith(
        mockUser.id,
        dto.username,
      );
    });

    it('should throw BadRequestException if username is the same', async () => {
      repository.findById.mockResolvedValue(mockUser);
      const sameUsernameDto = { username: mockUser.username };

      await expect(
        service.updateUsername(mockUser.id, sameUsernameDto, mockMeta),
      ).rejects.toThrow('New username is the same as the current one');
    });

    it('should throw ConflictException if username is already taken', async () => {
      repository.findById.mockResolvedValue(mockUser);
      const prismaError = new Prisma.PrismaClientKnownRequestError(
        'Unique constraint failed on the fields: (`username`)',
        {
          code: 'P2002',
          clientVersion: '5.0.0',
        },
      );
      repository.updateUsername.mockRejectedValue(prismaError);

      await expect(
        service.updateUsername(mockUser.id, dto, mockMeta),
      ).rejects.toThrow('Username is already taken');
    });
  });

  describe('changePassword', () => {
    const dto = {
      currentPassword: 'OldPassword@123',
      newPassword: 'NewPassword@1234',
    };

    it('should update password successfully', async () => {
      repository.findById.mockResolvedValue(mockUser);
      (bcrypt.compare as jest.Mock)
        .mockResolvedValueOnce(true) // current valid
        .mockResolvedValueOnce(false); // not same as old
      (bcrypt.hash as jest.Mock).mockResolvedValue('hashed_new');
      repository.updatePassword.mockResolvedValue({
        ...mockUser,
        passwordHash: 'hashed_new',
      });

      await service.changePassword(mockUser.id, dto, mockMeta);

      expect(repository.updatePassword).toHaveBeenCalledWith(
        mockUser.id,
        'hashed_new',
      );
      expect(eventEmitter.emit).toHaveBeenCalledWith(
        AUDIT_LOG_EVENT,
        expect.any(Object),
      );
    });

    it('should throw UnauthorizedException if current password wrong', async () => {
      repository.findById.mockResolvedValue(mockUser);
      (bcrypt.compare as jest.Mock).mockResolvedValue(false);

      await expect(
        service.changePassword(mockUser.id, dto, mockMeta),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('should throw BadRequestException if new password same as old', async () => {
      repository.findById.mockResolvedValue(mockUser);
      (bcrypt.compare as jest.Mock).mockResolvedValue(true); // both valid and same

      await expect(
        service.changePassword(mockUser.id, dto, mockMeta),
      ).rejects.toThrow('New password cannot be the same as the current one');
    });
  });

  describe('upgradeSubscription', () => {
    it('should upgrade a BASIC user to PREMIUM', async () => {
      repository.findById.mockResolvedValue(mockUser);
      repository.upgradeToPremium.mockResolvedValue({
        ...mockUser,
        subscriptionTier: SubscriptionTier.PREMIUM,
      });

      const result = await service.upgradeSubscription(mockUser.id, mockMeta);

      expect(result.subscriptionTier).toBe(SubscriptionTier.PREMIUM);
      expect(repository.upgradeToPremium).toHaveBeenCalledWith(mockUser.id);
      expect(eventEmitter.emit).toHaveBeenCalledWith(
        AUDIT_LOG_EVENT,
        expect.any(Object),
      );
    });

    it('should throw BadRequestException if user is already PREMIUM', async () => {
      repository.findById.mockResolvedValue({
        ...mockUser,
        subscriptionTier: SubscriptionTier.PREMIUM,
      });

      await expect(
        service.upgradeSubscription(mockUser.id, mockMeta),
      ).rejects.toThrow('User is already on the PREMIUM subscription tier');
      expect(repository.upgradeToPremium).not.toHaveBeenCalled();
    });

    it('should throw BadRequestException when upgrade is rejected atomically', async () => {
      repository.findById.mockResolvedValue(mockUser);
      repository.upgradeToPremium.mockResolvedValue(null);

      await expect(
        service.upgradeSubscription(mockUser.id, mockMeta),
      ).rejects.toThrow('User is already on the PREMIUM subscription tier');
      expect(eventEmitter.emit).not.toHaveBeenCalled();
    });
  });
});
