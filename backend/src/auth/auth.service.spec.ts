import { Test, TestingModule } from '@nestjs/testing';
import {
  ConflictException,
  UnauthorizedException,
  BadRequestException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { AuthService } from './auth.service';
import { UsersService } from '../users/users.service';
import type { User } from '@prisma/client';

jest.mock('bcrypt');

const mockUser: User = {
  id: 'user-uuid-123',
  email: 'test@example.com',
  username: 'testuser',
  passwordHash: '$2b$10$hashedpassword',
  isEmailVerified: false,
  emailVerificationToken: null,
  passwordResetToken: null,
  passwordResetExpires: null,
  googleId: null,
  facebookId: null,
  publicInfo: null,
  friendInfo: null,
  privateInfo: null,
  preferences: null,
  createdAt: new Date(),
  updatedAt: new Date(),
};

describe('AuthService', () => {
  let authService: AuthService;
  let usersService: jest.Mocked<UsersService>;
  let jwtService: jest.Mocked<JwtService>;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        {
          provide: UsersService,
          useValue: {
            findByEmail: jest.fn(),
            findByUsername: jest.fn(),
            findById: jest.fn(),
            create: jest.fn(),
          },
        },
        {
          provide: JwtService,
          useValue: {
            sign: jest.fn().mockReturnValue('signed-jwt-token'),
            verify: jest.fn(),
          },
        },
      ],
    }).compile();

    authService = module.get<AuthService>(AuthService);
    usersService = module.get(UsersService);
    jwtService = module.get(JwtService);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  // ─── REGISTER ─────────────────────────────────────────

  describe('register', () => {
    const registerDto = {
      email: 'new@example.com',
      username: 'newuser',
      password: 'Valid@123',
      emailVerificationToken: 'valid-token',
    };

    beforeEach(() => {
      // Default: verification token is valid and matches the email
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

      const result = await authService.register(registerDto);

      expect(result).toEqual({ access_token: 'signed-jwt-token' });
      expect(jwtService.verify).toHaveBeenCalledWith(
        registerDto.emailVerificationToken,
      );
      expect(usersService.findByEmail).toHaveBeenCalledWith(registerDto.email);
      expect(usersService.findByUsername).toHaveBeenCalledWith(
        registerDto.username,
      );
      expect(bcrypt.hash).toHaveBeenCalledWith(registerDto.password, 10);
      expect(usersService.create).toHaveBeenCalledWith(
        registerDto.email,
        registerDto.username,
        '$2b$10$hashed',
      );
    });

    it('should throw BadRequestException if verification token email does not match', async () => {
      jwtService.verify.mockReturnValue({
        email: 'different@example.com',
        purpose: 'email_verification',
      });

      await expect(authService.register(registerDto)).rejects.toThrow(
        BadRequestException,
      );
      await expect(authService.register(registerDto)).rejects.toThrow(
        'Verification token does not match the provided email',
      );
      expect(usersService.create).not.toHaveBeenCalled();
    });

    it('should throw BadRequestException if verification token is invalid', async () => {
      jwtService.verify.mockImplementation(() => {
        throw new Error('invalid token');
      });

      await expect(authService.register(registerDto)).rejects.toThrow(
        BadRequestException,
      );
      await expect(authService.register(registerDto)).rejects.toThrow(
        'Invalid or expired email verification token',
      );
    });

    it('should throw BadRequestException if token purpose is wrong', async () => {
      jwtService.verify.mockReturnValue({
        email: registerDto.email,
        purpose: 'password_reset',
      });

      await expect(authService.register(registerDto)).rejects.toThrow(
        BadRequestException,
      );
    });

    it('should throw ConflictException if email already exists', async () => {
      usersService.findByEmail.mockResolvedValue(mockUser);

      await expect(authService.register(registerDto)).rejects.toThrow(
        ConflictException,
      );
      await expect(authService.register(registerDto)).rejects.toThrow(
        'Email already registered',
      );
      expect(usersService.create).not.toHaveBeenCalled();
    });

    it('should throw ConflictException if username already exists', async () => {
      usersService.findByEmail.mockResolvedValue(null);
      usersService.findByUsername.mockResolvedValue(mockUser);

      await expect(authService.register(registerDto)).rejects.toThrow(
        ConflictException,
      );
      await expect(authService.register(registerDto)).rejects.toThrow(
        'Username already taken',
      );
      expect(usersService.create).not.toHaveBeenCalled();
    });
  });

  // ─── LOGIN ────────────────────────────────────────────

  describe('login', () => {
    const loginDto = {
      email: 'test@example.com',
      password: 'password123',
    };

    it('should login and return an access token for valid credentials (email)', async () => {
      usersService.findByEmail.mockResolvedValue(mockUser);
      (bcrypt.compare as jest.Mock).mockResolvedValue(true);

      const result = await authService.login(loginDto);

      expect(result).toEqual({ access_token: 'signed-jwt-token' });
      expect(usersService.findByEmail).toHaveBeenCalledWith(loginDto.email);
      expect(bcrypt.compare).toHaveBeenCalledWith(
        loginDto.password,
        mockUser.passwordHash,
      );
      expect(jwtService.sign).toHaveBeenCalledWith({
        sub: mockUser.id,
        email: mockUser.email,
      });
    });

    it('should login and return an access token for valid credentials (username)', async () => {
      const usernameLoginDto = {
        email: 'testuser',
        password: 'password123',
      };
      usersService.findByUsername.mockResolvedValue(mockUser);
      (bcrypt.compare as jest.Mock).mockResolvedValue(true);

      const result = await authService.login(usernameLoginDto);

      expect(result).toEqual({ access_token: 'signed-jwt-token' });
      expect(usersService.findByUsername).toHaveBeenCalledWith('testuser');
      expect(usersService.findByEmail).not.toHaveBeenCalled();
    });

    it('should throw UnauthorizedException if user does not exist', async () => {
      usersService.findByEmail.mockResolvedValue(null);

      await expect(authService.login(loginDto)).rejects.toThrow(
        UnauthorizedException,
      );
      await expect(authService.login(loginDto)).rejects.toThrow(
        'Invalid credentials',
      );
    });

    it('should throw UnauthorizedException if user has no passwordHash (OAuth-only account)', async () => {
      usersService.findByEmail.mockResolvedValue({
        ...mockUser,
        passwordHash: null,
      });

      await expect(authService.login(loginDto)).rejects.toThrow(
        UnauthorizedException,
      );
    });

    it('should throw UnauthorizedException if password is incorrect', async () => {
      usersService.findByEmail.mockResolvedValue(mockUser);
      (bcrypt.compare as jest.Mock).mockResolvedValue(false);

      await expect(authService.login(loginDto)).rejects.toThrow(
        UnauthorizedException,
      );
      await expect(authService.login(loginDto)).rejects.toThrow(
        'Invalid credentials',
      );
    });
  });
});
