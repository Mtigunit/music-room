import { Test, TestingModule } from '@nestjs/testing';
import { ConflictException, UnauthorizedException } from '@nestjs/common';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { OtpService } from '../otp/otp.service';

describe('AuthController', () => {
  let controller: AuthController;
  let authService: jest.Mocked<AuthService>;
  let otpService: jest.Mocked<OtpService>;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [AuthController],
      providers: [
        {
          provide: AuthService,
          useValue: {
            register: jest.fn(),
            login: jest.fn(),
          },
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

    controller = module.get<AuthController>(AuthController);
    authService = module.get(AuthService) as jest.Mocked<AuthService>;
    otpService = module.get(OtpService) as jest.Mocked<OtpService>;
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  // ─── SEND OTP ─────────────────────────────────────────

  describe('sendOtp', () => {
    it('should call otpService.sendOtp and return success message', async () => {
      otpService.sendOtp.mockResolvedValue(undefined);

      const result = await controller.sendOtp({ email: 'a@b.com' });

      expect(result).toEqual({ message: 'OTP sent successfully' });
      expect(otpService.sendOtp).toHaveBeenCalledWith('a@b.com');
    });

    it('should propagate ConflictException for registered emails', async () => {
      otpService.sendOtp.mockRejectedValue(
        new ConflictException('Email already registered'),
      );

      await expect(
        controller.sendOtp({ email: 'taken@b.com' }),
      ).rejects.toThrow(ConflictException);
    });
  });

  // ─── VERIFY OTP ───────────────────────────────────────

  describe('verifyOtp', () => {
    it('should call otpService.verifyOtp and return verification token', async () => {
      const expected = { emailVerificationToken: 'token-123' };
      otpService.verifyOtp.mockResolvedValue(expected);

      const result = await controller.verifyOtp({
        email: 'a@b.com',
        code: '472915',
      });

      expect(result).toEqual(expected);
      expect(otpService.verifyOtp).toHaveBeenCalledWith('a@b.com', '472915');
    });
  });

  // ─── REGISTER ─────────────────────────────────────────

  describe('register', () => {
    const registerDto = {
      email: 'test@example.com',
      username: 'testuser',
      password: 'Valid@123',
      emailVerificationToken: 'valid-token',
    };

    it('should call authService.register and return the token', async () => {
      const expectedResult = { access_token: 'jwt-token' };
      authService.register.mockResolvedValue(expectedResult);

      const result = await controller.register(registerDto);

      expect(result).toEqual(expectedResult);
      expect(authService.register).toHaveBeenCalledWith(registerDto);
    });

    it('should propagate ConflictException from service', async () => {
      authService.register.mockRejectedValue(
        new ConflictException('Email already registered'),
      );

      await expect(controller.register(registerDto)).rejects.toThrow(
        ConflictException,
      );
    });
  });

  // ─── LOGIN ────────────────────────────────────────────

  describe('login', () => {
    const loginDto = {
      email: 'test@example.com',
      password: 'password123',
    };

    it('should call authService.login and return the token', async () => {
      const expectedResult = { access_token: 'jwt-token' };
      authService.login.mockResolvedValue(expectedResult);

      const result = await controller.login(loginDto);

      expect(result).toEqual(expectedResult);
      expect(authService.login).toHaveBeenCalledWith(loginDto);
    });

    it('should propagate UnauthorizedException from service', async () => {
      authService.login.mockRejectedValue(
        new UnauthorizedException('Invalid credentials'),
      );

      await expect(controller.login(loginDto)).rejects.toThrow(
        UnauthorizedException,
      );
    });
  });

  // ─── PROFILE ──────────────────────────────────────────

  describe('getProfile', () => {
    it('should return the user from the request object', () => {
      const mockReq = { user: { id: 'user-uuid', email: 'a@b.com' } };

      const result = controller.getProfile(mockReq);

      expect(result).toEqual({ id: 'user-uuid', email: 'a@b.com' });
    });
  });
});
