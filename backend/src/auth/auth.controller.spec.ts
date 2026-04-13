import { Test, TestingModule } from '@nestjs/testing';
import { ConflictException, UnauthorizedException } from '@nestjs/common';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';

describe('AuthController', () => {
  let controller: AuthController;
  let authService: jest.Mocked<AuthService>;

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
      ],
    }).compile();

    controller = module.get<AuthController>(AuthController);
    authService = module.get(AuthService) as jest.Mocked<AuthService>;
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  // ─── REGISTER ─────────────────────────────────────────

  describe('register', () => {
    const registerDto = {
      email: 'test@example.com',
      username: 'testuser',
      password: 'password123',
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
