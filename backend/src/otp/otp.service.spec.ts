import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { OtpService } from './otp.service';
import { RedisService } from '../redis/redis.service';
import { MailService } from '../mail/mail.service';

describe('OtpService', () => {
  let otpService: OtpService;
  let redisClient: Record<string, jest.Mock>;
  let mailService: jest.Mocked<MailService>;

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
          provide: JwtService,
          useValue: {
            sign: jest.fn().mockReturnValue('verification-token'),
          },
        },
      ],
    }).compile();

    otpService = module.get<OtpService>(OtpService);
    mailService = module.get(MailService);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  // ─── sendOtp ──────────────────────────────────────────

  describe('sendOtp', () => {
    it('should generate and send an OTP', async () => {
      redisClient.incr.mockResolvedValue(1);

      await otpService.sendOtp('test@example.com');

      expect(redisClient.set).toHaveBeenCalledWith(
        'otp:email_verification:test@example.com',
        expect.stringMatching(/^\d{6}$/),
        'EX',
        300,
      );
      expect(redisClient.set).toHaveBeenCalledWith(
        'otp:attempts:email_verification:test@example.com',
        '0',
        'EX',
        300,
      );
      expect(mailService.sendOtpEmail).toHaveBeenCalledWith(
        'test@example.com',
        expect.stringMatching(/^\d{6}$/),
        'email_verification',
      );
    });

    it('should support email_update with targetEmail and data', async () => {
      redisClient.incr.mockResolvedValue(1);

      await otpService.sendOtp('user-id', 'email_update', 'new@email.com', {
        newEmail: 'new@email.com',
      });

      expect(redisClient.set).toHaveBeenCalledWith(
        'otp:email_update:user-id',
        expect.stringMatching(/^\d{6}$/),
        'EX',
        300,
      );
      expect(redisClient.set).toHaveBeenCalledWith(
        'otp:data:email_update:user-id',
        JSON.stringify({ newEmail: 'new@email.com' }),
        'EX',
        300,
      );
      expect(mailService.sendOtpEmail).toHaveBeenCalledWith(
        'new@email.com',
        expect.stringMatching(/^\d{6}$/),
        'email_update',
      );
    });

    it('should throw BadRequestException when rate limit is exceeded', async () => {
      redisClient.incr.mockResolvedValue(6); // Max is 5, so 6 is exceeded

      await expect(otpService.sendOtp('test@example.com')).rejects.toThrow(
        BadRequestException,
      );
    });
  });

  // ─── verifyOtp ────────────────────────────────────────

  describe('verifyOtp', () => {
    it('should verify OTP and return data if present', async () => {
      redisClient.get
        .mockResolvedValueOnce('123456') // stored code
        .mockResolvedValueOnce(JSON.stringify({ foo: 'bar' })); // stored data
      redisClient.incr.mockResolvedValue(1); // 1st attempt

      const result = await otpService.verifyOtp(
        'id123',
        '123456',
        'email_update',
      );

      expect(result).toEqual({
        token: 'verification-token',
        data: { foo: 'bar' },
      });
      expect(redisClient.del).toHaveBeenCalledWith(
        'otp:email_update:id123',
        'otp:attempts:email_update:id123',
        'otp:data:email_update:id123',
      );
    });

    it('should throw BadRequestException for wrong code', async () => {
      redisClient.get.mockResolvedValueOnce('654321'); // stored code
      redisClient.incr.mockResolvedValue(1); // 1st attempt

      await expect(otpService.verifyOtp('id123', '123456')).rejects.toThrow(
        BadRequestException,
      );
      expect(redisClient.incr).toHaveBeenCalled();
    });

    it('should throw BadRequestException when brute-force limit is exceeded', async () => {
      redisClient.get.mockResolvedValueOnce('123456'); // stored code
      redisClient.incr.mockResolvedValue(6); // 6th attempt (max is 5)

      await expect(otpService.verifyOtp('id123', '123456')).rejects.toThrow(
        BadRequestException,
      );
      expect(redisClient.del).toHaveBeenCalledWith(
        'otp:email_verification:id123',
        'otp:attempts:email_verification:id123',
        'otp:data:email_verification:id123',
      );
    });
  });
});
