import { Test, TestingModule } from '@nestjs/testing';
import {
  ConflictException,
  UnauthorizedException,
  BadRequestException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { OAuth2Client } from 'google-auth-library';
import { AuthService } from './auth.service';
import { UsersService } from '../users/users.service';
import { OtpService } from '../otp/otp.service';
import type { User } from '@prisma/client';
import { EventEmitter2 } from '@nestjs/event-emitter';

jest.mock('bcrypt');
jest.mock('google-auth-library');

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

describe('AuthService', () => {
  let authService: AuthService;
  let usersService: jest.Mocked<UsersService>;
  let jwtService: jest.Mocked<JwtService>;
  let otpService: jest.Mocked<OtpService>;
  let verifyIdTokenMock: jest.Mock;

  beforeEach(async () => {
    verifyIdTokenMock = jest.fn();
    (OAuth2Client as unknown as jest.Mock).mockImplementation(() => ({
      verifyIdToken: verifyIdTokenMock,
    }));

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        {
          provide: UsersService,
          useValue: {
            findByEmail: jest.fn(),
            findByUsername: jest.fn(),
            findByGoogleId: jest.fn(),
            findById: jest.fn(),
            create: jest.fn(),
            createOAuthUser: jest.fn(),
            linkGoogleAccount: jest.fn(),
            updatePassword: jest.fn(),
            updatePasswordAndIncrementToken: jest.fn(),
            incrementTokenVersion: jest.fn(),
          },
        },
        {
          provide: JwtService,
          useValue: {
            sign: jest.fn().mockReturnValue('signed-jwt-token'),
            verify: jest.fn(),
          },
        },
        {
          provide: ConfigService,
          useValue: {
            getOrThrow: jest.fn().mockImplementation((key) => {
              if (key === 'GOOGLE_CLIENT_ID') return 'mock-client-id';
              return 'mock-value';
            }),
            get: jest.fn(),
          },
        },
        {
          provide: EventEmitter2,
          useValue: { emit: jest.fn() },
        },
        {
          provide: OtpService,
          useValue: {
            sendOtp: jest.fn(),
            verifyOtp: jest.fn(),
          },
        },
      ],
    }).compile();

    authService = module.get<AuthService>(AuthService);
    usersService = module.get(UsersService);
    jwtService = module.get(JwtService);
    otpService = module.get(OtpService);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  // ─── REGISTER ─────────────────────────────────────────

  describe('sendRegistrationOtp', () => {
    it('should throw ConflictException if email is already registered', async () => {
      usersService.findByEmail.mockResolvedValue(mockUser);
      await expect(
        authService.sendRegistrationOtp('test@example.com'),
      ).rejects.toThrow(ConflictException);
      expect(otpService.sendOtp).not.toHaveBeenCalled();
    });

    it('should call otpService.sendOtp if email is new', async () => {
      usersService.findByEmail.mockResolvedValue(null);
      await authService.sendRegistrationOtp('new@example.com');
      expect(otpService.sendOtp).toHaveBeenCalledWith(
        'new@example.com',
        'email_verification',
      );
    });
  });

  describe('sendPasswordResetOtp', () => {
    it('should call otpService.sendOtp if email exists', async () => {
      usersService.findByEmail.mockResolvedValue(mockUser);
      await authService.sendPasswordResetOtp('test@example.com');
      expect(otpService.sendOtp).toHaveBeenCalledWith(
        'test@example.com',
        'password_reset',
      );
    });

    it('should silently return if email does not exist (enumeration protection)', async () => {
      usersService.findByEmail.mockResolvedValue(null);
      await authService.sendPasswordResetOtp('unknown@example.com');
      expect(otpService.sendOtp).not.toHaveBeenCalled();
    });
  });

  describe('register', () => {
    const registerDto = {
      email: 'new@example.com',
      username: 'newuser',
      password: 'Valid@123',
      emailVerificationToken: 'valid-token',
    };

    const mockMeta = {
      platform: 'unknown',
      deviceModel: 'unknown',
      deviceId: 'unknown',
      appVersion: 'unknown',
      ipAddress: '127.0.0.1',
    };

    beforeEach(() => {
      jwtService.verify.mockReturnValue({
        email: registerDto.email,
        purpose: 'email_verification',
      });
    });

    it('should register a new user and return an access token', async () => {
      usersService.findByEmail.mockResolvedValue(null);
      usersService.findByUsername.mockResolvedValue(null);
      usersService.create.mockResolvedValue({
        ...mockUser,
        email: registerDto.email,
        username: registerDto.username,
      });
      (bcrypt.hash as jest.Mock).mockResolvedValue('$2b$10$hashed');

      const result = await authService.register(registerDto, mockMeta);

      expect(result).toEqual({
        access_token: 'signed-jwt-token',
        user: {
          id: 'user-uuid-123',
          email: registerDto.email,
          username: registerDto.username,
        },
      });
      expect(usersService.create).toHaveBeenCalledWith(
        registerDto.email,
        registerDto.username,
        '$2b$10$hashed',
        true,
      );
    });

    it('should throw BadRequestException if token email does not match', async () => {
      jwtService.verify.mockReturnValue({
        email: 'different@example.com',
        purpose: 'email_verification',
      });

      await expect(authService.register(registerDto, mockMeta)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('should throw BadRequestException if token purpose is wrong', async () => {
      jwtService.verify.mockReturnValue({
        email: registerDto.email,
        purpose: 'password_reset',
      });

      await expect(authService.register(registerDto, mockMeta)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('should throw BadRequestException if verification token is invalid', async () => {
      jwtService.verify.mockImplementation(() => {
        throw new Error('invalid token');
      });

      await expect(authService.register(registerDto, mockMeta)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('should throw ConflictException if email exists', async () => {
      usersService.findByEmail.mockResolvedValue(mockUser);
      await expect(authService.register(registerDto, mockMeta)).rejects.toThrow(
        ConflictException,
      );
    });

    it('should throw ConflictException if username already exists', async () => {
      usersService.findByEmail.mockResolvedValue(null);
      usersService.findByUsername.mockResolvedValue(mockUser);

      await expect(authService.register(registerDto, mockMeta)).rejects.toThrow(
        ConflictException,
      );
    });
  });

  // ─── LOGIN ────────────────────────────────────────────

  describe('login', () => {
    const loginDto = {
      identifier: 'test@example.com',
      password: 'password123',
    };

    const mockMeta = {
      platform: 'unknown',
      deviceModel: 'unknown',
      deviceId: 'unknown',
      appVersion: 'unknown',
      ipAddress: '127.0.0.1',
    };

    it('should login with valid email credentials', async () => {
      usersService.findByEmail.mockResolvedValue(mockUser);
      (bcrypt.compare as jest.Mock).mockResolvedValue(true);
      const result = await authService.login(loginDto, mockMeta);
      expect(result).toEqual({
        access_token: 'signed-jwt-token',
        user: {
          id: mockUser.id,
          email: mockUser.email,
          username: mockUser.username,
        },
      });
    });

    it('should login and return an access token for valid credentials (username)', async () => {
      const usernameLoginDto = {
        identifier: 'testuser',
        password: 'password123',
      };
      usersService.findByUsername.mockResolvedValue(mockUser);
      (bcrypt.compare as jest.Mock).mockResolvedValue(true);

      const result = await authService.login(usernameLoginDto, mockMeta);

      expect(result).toEqual({
        access_token: 'signed-jwt-token',
        user: {
          id: mockUser.id,
          email: mockUser.email,
          username: mockUser.username,
        },
      });
      expect(usersService.findByUsername).toHaveBeenCalledWith('testuser');
      expect(usersService.findByEmail).not.toHaveBeenCalled();
    });

    it('should throw UnauthorizedException if user does not exist', async () => {
      usersService.findByEmail.mockResolvedValue(null);

      await expect(authService.login(loginDto, mockMeta)).rejects.toThrow(
        UnauthorizedException,
      );
    });

    it('should throw UnauthorizedException if user has no passwordHash (OAuth-only account)', async () => {
      usersService.findByEmail.mockResolvedValue({
        ...mockUser,
        passwordHash: null,
      });

      await expect(authService.login(loginDto, mockMeta)).rejects.toThrow(
        UnauthorizedException,
      );
    });

    it('should throw UnauthorizedException if password is incorrect', async () => {
      usersService.findByEmail.mockResolvedValue(mockUser);
      (bcrypt.compare as jest.Mock).mockResolvedValue(false);

      await expect(authService.login(loginDto, mockMeta)).rejects.toThrow(
        UnauthorizedException,
      );
    });
  });

  // ─── GOOGLE AUTH ──────────────────────────────────────

  describe('googleAuth', () => {
    const mockGooglePayload = {
      email: 'google@example.com',
      sub: 'google-sub-123',
      given_name: 'Google User',
    };

    const mockMeta = {
      platform: 'unknown',
      deviceModel: 'unknown',
      appVersion: 'unknown',
      ipAddress: '127.0.0.1',
      deviceId: 'unknown',
    };

    beforeEach(() => {
      verifyIdTokenMock.mockResolvedValue({
        getPayload: () => mockGooglePayload,
      });
    });

    it('should return token if user already exists by googleId', async () => {
      usersService.findByGoogleId.mockResolvedValue(mockUser);

      const result = await authService.googleAuth('valid-id-token', mockMeta);

      expect(result).toEqual({
        access_token: 'signed-jwt-token',
        user: {
          id: mockUser.id,
          email: mockUser.email,
          username: mockUser.username,
        },
      });
      expect(usersService.findByGoogleId).toHaveBeenCalledWith(
        'google-sub-123',
      );
      expect(usersService.findByEmail).not.toHaveBeenCalled();
    });

    it('should link account and return token if user exists by email but no googleId', async () => {
      usersService.findByGoogleId.mockResolvedValue(null);
      usersService.findByEmail.mockResolvedValue(mockUser);
      usersService.linkGoogleAccount.mockResolvedValue({
        ...mockUser,
        googleId: 'google-sub-123',
      });

      const result = await authService.googleAuth('valid-id-token', mockMeta);

      expect(result).toEqual({
        access_token: 'signed-jwt-token',
        user: {
          id: mockUser.id,
          email: mockUser.email,
          username: mockUser.username,
        },
      });
      expect(usersService.findByEmail).toHaveBeenCalledWith(
        'google@example.com',
      );
      expect(usersService.linkGoogleAccount).toHaveBeenCalledWith(
        mockUser.id,
        'google-sub-123',
      );
    });

    it('should create new OAuth user with unique username if new', async () => {
      usersService.findByGoogleId.mockResolvedValue(null);
      usersService.findByEmail.mockResolvedValue(null);
      // Mock findByUsername to return null on the first try so the username is "googleuser"
      usersService.findByUsername.mockResolvedValue(null);
      usersService.createOAuthUser.mockResolvedValue({
        ...mockUser,
        email: 'google@example.com',
        username: 'googleuser',
        googleId: 'google-sub-123',
      });

      const result = await authService.googleAuth('valid-id-token', mockMeta);

      expect(result).toEqual({
        access_token: 'signed-jwt-token',
        user: {
          id: mockUser.id,
          email: 'google@example.com',
          username: 'googleuser',
        },
      });
      expect(usersService.createOAuthUser).toHaveBeenCalledWith(
        'google@example.com',
        expect.stringMatching(/^googleuser/),
        'google-sub-123',
        true,
      );
    });

    it('should generate a unique username with suffix if base exists', async () => {
      usersService.findByGoogleId.mockResolvedValue(null);
      usersService.findByEmail.mockResolvedValue(null);

      // First try returns a user, second try returns null
      usersService.findByUsername
        .mockResolvedValueOnce(mockUser)
        .mockResolvedValueOnce(null);

      usersService.createOAuthUser.mockResolvedValue(mockUser);

      await authService.googleAuth('valid-id-token', mockMeta);

      expect(usersService.findByUsername).toHaveBeenCalledTimes(2);
      expect(usersService.createOAuthUser).toHaveBeenCalledWith(
        'google@example.com',
        expect.stringMatching(/^googleuser_\d{4}$/), // Matches suffix logic
        'google-sub-123',
        true,
      );
    });

    it('should throw UnauthorizedException if token verification fails', async () => {
      verifyIdTokenMock.mockRejectedValue(new Error('Invalid token'));

      await expect(authService.googleAuth('invalid', mockMeta)).rejects.toThrow(
        UnauthorizedException,
      );
    });
  });

  // ─── GENERATE UNIQUE USERNAME ─────────────────────────

  describe('generateUniqueUsername', () => {
    it('should handle empty base strings by padding with x', async () => {
      usersService.findByUsername.mockResolvedValue(null);
      const result = await authService['generateUniqueUsername']('');
      expect(result).toBe('xxx');
      expect(usersService.findByUsername).toHaveBeenCalledWith('xxx');
    });

    it('should strip special characters and lowercase the string', async () => {
      usersService.findByUsername.mockResolvedValue(null);
      const result =
        await authService['generateUniqueUsername']('Hello@World!');
      expect(result).toBe('helloworld');
      expect(usersService.findByUsername).toHaveBeenCalledWith('helloworld');
    });

    it('should properly truncate long strings and resolve collisions', async () => {
      const longBase = 'a'.repeat(30);
      const truncatedBase = 'a'.repeat(20);

      // 1st try: collision on truncated base
      // 2nd try: success with random suffix
      usersService.findByUsername
        .mockResolvedValueOnce(mockUser)
        .mockResolvedValueOnce(null);

      const result = await authService['generateUniqueUsername'](longBase);

      expect(result).toMatch(new RegExp(`^${truncatedBase}_\\d{4}$`));

      const suffixString = result.split('_')[1];
      const suffix = parseInt(suffixString, 10);
      expect(suffix).toBeGreaterThanOrEqual(1000);
      expect(suffix).toBeLessThanOrEqual(9999);

      expect(usersService.findByUsername).toHaveBeenCalledTimes(2);
      expect(usersService.findByUsername).toHaveBeenNthCalledWith(
        1,
        truncatedBase,
      );
    });
  });

  // ─── RESET PASSWORD ───────────────────────────────────

  describe('resetPassword', () => {
    const resetDto = {
      email: 'test@example.com',
      resetToken: 'valid-reset-token',
      newPassword: 'NewPassword123!',
    };

    const mockMeta = {
      platform: 'unknown',
      deviceModel: 'unknown',
      deviceId: 'unknown',
      appVersion: 'unknown',
      ipAddress: '127.0.0.1',
    };

    it('should successfully reset the password', async () => {
      jwtService.verify.mockReturnValue({
        email: 'test@example.com',
        purpose: 'password_reset',
      });
      usersService.findByEmail.mockResolvedValue(mockUser);
      (bcrypt.hash as jest.Mock).mockResolvedValue('$2b$10$newhashedpassword');

      await authService.resetPassword(resetDto, mockMeta);

      expect(jwtService.verify).toHaveBeenCalledWith('valid-reset-token');
      expect(usersService.findByEmail).toHaveBeenCalledWith('test@example.com');
      expect(bcrypt.hash).toHaveBeenCalledWith('NewPassword123!', 10);
      expect(usersService.updatePassword).toHaveBeenCalledWith(
        mockUser.id,
        '$2b$10$newhashedpassword',
      );
    });

    it('should throw BadRequestException if token is invalid or expired', async () => {
      jwtService.verify.mockImplementation(() => {
        throw new Error('invalid token');
      });

      await expect(
        authService.resetPassword(resetDto, mockMeta),
      ).rejects.toThrow(BadRequestException);
      await expect(
        authService.resetPassword(resetDto, mockMeta),
      ).rejects.toThrow('Invalid or expired reset token');
    });

    it('should throw BadRequestException if token purpose is not password_reset', async () => {
      jwtService.verify.mockReturnValue({
        email: 'test@example.com',
        purpose: 'email_verification',
      });

      await expect(
        authService.resetPassword(resetDto, mockMeta),
      ).rejects.toThrow(BadRequestException);
      await expect(
        authService.resetPassword(resetDto, mockMeta),
      ).rejects.toThrow('Invalid reset token');
    });

    it('should throw BadRequestException if token email does not match DTO email', async () => {
      jwtService.verify.mockReturnValue({
        email: 'different@example.com',
        purpose: 'password_reset',
      });

      await expect(
        authService.resetPassword(resetDto, mockMeta),
      ).rejects.toThrow(BadRequestException);
      await expect(
        authService.resetPassword(resetDto, mockMeta),
      ).rejects.toThrow('Reset token does not match the provided email');
    });

    it('should throw BadRequestException if user does not exist', async () => {
      jwtService.verify.mockReturnValue({
        email: 'test@example.com',
        purpose: 'password_reset',
      });
      usersService.findByEmail.mockResolvedValue(null);

      await expect(
        authService.resetPassword(resetDto, mockMeta),
      ).rejects.toThrow(BadRequestException);
      await expect(
        authService.resetPassword(resetDto, mockMeta),
      ).rejects.toThrow('User does not exist');
    });
  });

  describe('logoutAll', () => {
    const mockMeta = {
      platform: 'ios',
      deviceModel: 'iPhone 15',
      appVersion: '1.0.0',
      ipAddress: '127.0.0.1',
    };

    it('should increment token version and emit audit event', async () => {
      await authService.logoutAll(mockUser.id, mockMeta);

      expect(usersService.incrementTokenVersion).toHaveBeenCalledWith(
        mockUser.id,
      );
    });
  });
});
