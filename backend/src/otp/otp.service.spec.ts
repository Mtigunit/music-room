import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, ConflictException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { OtpService } from './otp.service';
import { RedisService } from '../redis/redis.service';
import { MailService } from '../mail/mail.service';
import { UsersService } from '../users/users.service';
import type { User } from '@prisma/client';

const mockUser: User = {
  id: 'user-uuid-123',
  email: 'taken@example.com',
  username: 'takenuser',
  passwordHash: '$2b$10$hashed',
  isEmailVerified: false,
  googleId: null,
  publicInfo: null,
  friendInfo: null,
  privateInfo: null,
  preferences: null,
  createdAt: new Date(),
  updatedAt: new Date(),
};

describe('OtpService', () => {
  let otpService: OtpService;
  let redisClient: Record<string, jest.Mock>;
  let mailService: jest.Mocked<MailService>;
  let usersService: jest.Mocked<UsersService>;
  let jwtService: jest.Mocked<JwtService>;

  beforeEach(async () => {
    redisClient = {
      get: jest.fn(),
      set: jest.fn(),
      del: jest.fn(),
      incr: jest.fn(),
      exists: jest.fn(),
      expire: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OtpService,
        {
          provide: RedisService,
          useValue: {
            getClient: jest.fn().mockReturnValue(redisClient),
          },
        },
        {
          provide: MailService,
          useValue: {
            sendOtpEmail: jest.fn(),
          },
        },
        {
          provide: UsersService,
          useValue: {
            findByEmail: jest.fn(),
          },
        },
        {
          provide: JwtService,
          useValue: {
            sign: jest.fn().mockReturnValue('verification-token'),
          },
        },
      ],
    }).compile();

    otpService = module.get<OtpService>(OtpService);
    mailService = module.get(MailService);
    usersService = module.get(UsersService);
    jwtService = module.get(JwtService);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  // ─── sendOtp ──────────────────────────────────────────

  describe('sendOtp', () => {
    it('should generate and send an OTP for a new email', async () => {
      usersService.findByEmail.mockResolvedValue(null);
      redisClient.get.mockResolvedValue(null);
      redisClient.exists.mockResolvedValue(0);

      await otpService.sendOtp('new@example.com');

      expect(usersService.findByEmail).toHaveBeenCalledWith('new@example.com');
      expect(redisClient.set).toHaveBeenCalledWith(
        'otp:email_verification:new@example.com',
        expect.stringMatching(/^\d{6}$/),
        'EX',
        300,
      );
      expect(redisClient.set).toHaveBeenCalledWith(
        'otp:attempts:email_verification:new@example.com',
        '0',
        'EX',
        300,
      );
      expect(mailService.sendOtpEmail).toHaveBeenCalledWith(
        'new@example.com',
        expect.stringMatching(/^\d{6}$/),
        'email_verification',
      );
    });

    it('should throw ConflictException if email is already registered', async () => {
      usersService.findByEmail.mockResolvedValue(mockUser);

      await expect(otpService.sendOtp('taken@example.com')).rejects.toThrow(
        ConflictException,
      );
      await expect(otpService.sendOtp('taken@example.com')).rejects.toThrow(
        'Email already registered',
      );
      expect(mailService.sendOtpEmail).not.toHaveBeenCalled();
    });

    it('should throw BadRequestException when rate limit is exceeded', async () => {
      usersService.findByEmail.mockResolvedValue(null);
      redisClient.get.mockResolvedValue('5'); // Already at max

      await expect(otpService.sendOtp('new@example.com')).rejects.toThrow(
        BadRequestException,
      );
      await expect(otpService.sendOtp('new@example.com')).rejects.toThrow(
        'Too many OTP requests',
      );
    });

    it('should set rate limit expiry on first request', async () => {
      usersService.findByEmail.mockResolvedValue(null);
      redisClient.get.mockResolvedValue(null);
      redisClient.exists.mockResolvedValue(0);

      await otpService.sendOtp('new@example.com');

      expect(redisClient.expire).toHaveBeenCalledWith(
        'otp:rate:email_verification:new@example.com',
        900,
      );
    });

    it('should not reset rate limit expiry on subsequent requests', async () => {
      usersService.findByEmail.mockResolvedValue(null);
      redisClient.get.mockResolvedValue('2');
      redisClient.exists.mockResolvedValue(1);

      await otpService.sendOtp('new@example.com');

      expect(redisClient.expire).not.toHaveBeenCalled();
    });
  });

  // ─── verifyOtp ────────────────────────────────────────

  describe('verifyOtp', () => {
    it('should verify OTP and return a verification token', async () => {
      redisClient.get
        .mockResolvedValueOnce('0') // attempts
        .mockResolvedValueOnce('123456'); // stored code

      const result = await otpService.verifyOtp('a@b.com', '123456');

      expect(result).toEqual({ token: 'verification-token' });
      expect(redisClient.del).toHaveBeenCalledWith(
        'otp:email_verification:a@b.com',
        'otp:attempts:email_verification:a@b.com',
      );
      expect(jwtService.sign).toHaveBeenCalledWith(
        { email: 'a@b.com', purpose: 'email_verification' },
        { expiresIn: '10m' },
      );
    });

    it('should throw BadRequestException for expired or missing OTP', async () => {
      redisClient.get
        .mockResolvedValueOnce('0') // attempts
        .mockResolvedValueOnce(null); // no stored code

      await expect(otpService.verifyOtp('a@b.com', '123456')).rejects.toThrow(
        BadRequestException,
      );
      await expect(otpService.verifyOtp('a@b.com', '123456')).rejects.toThrow(
        'OTP expired or not found',
      );
    });

    it('should throw BadRequestException and increment attempts for wrong code', async () => {
      redisClient.get
        .mockResolvedValueOnce('0') // attempts (1st call)
        .mockResolvedValueOnce('654321') // stored code (1st call)
        .mockResolvedValueOnce('1') // attempts (2nd call)
        .mockResolvedValueOnce('654321'); // stored code (2nd call)

      await expect(otpService.verifyOtp('a@b.com', '123456')).rejects.toThrow(
        BadRequestException,
      );
      await expect(otpService.verifyOtp('a@b.com', '123456')).rejects.toThrow(
        'Invalid OTP',
      );
      expect(redisClient.incr).toHaveBeenCalledWith(
        'otp:attempts:email_verification:a@b.com',
      );
    });

    it('should delete OTP and throw after max verification attempts', async () => {
      redisClient.get
        .mockResolvedValueOnce('5') // attempts (1st call)
        .mockResolvedValueOnce('5'); // attempts (2nd call)

      await expect(otpService.verifyOtp('a@b.com', '123456')).rejects.toThrow(
        BadRequestException,
      );
      await expect(otpService.verifyOtp('a@b.com', '123456')).rejects.toThrow(
        'Too many failed attempts',
      );
      expect(redisClient.del).toHaveBeenCalledWith(
        'otp:email_verification:a@b.com',
        'otp:attempts:email_verification:a@b.com',
      );
    });
  });
});
