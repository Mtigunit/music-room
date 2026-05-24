import {
  Injectable,
  ConflictException,
  UnauthorizedException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { EventEmitter2, OnEvent } from '@nestjs/event-emitter';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import * as crypto from 'crypto';
import { OAuth2Client } from 'google-auth-library';
import { UsersService } from '../users/users.service';
import { OtpService, OtpVerificationPayload } from '../otp/otp.service';
import type { RegisterDto } from './dto/register.dto';
import type { LoginDto } from './dto/login.dto';
import type { ResetPasswordDto } from './dto/reset-password.dto';
import type { JwtPayload } from './interfaces/jwt-payload.interface';
import type { User } from '@prisma/client';
import { AUDIT_LOG_EVENT, AuditAction } from '../audit-log/audit-log.constants';
import { createAuditLogEvent } from '../audit-log/audit-log.event';
import type { ClientMetaDto } from '../common/dto/client-meta.dto';

const BCRYPT_SALT_ROUNDS = 10;
export const PASSWORD_RESET_REQUEST_EVENT = 'auth.password_reset_request';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);
  private readonly googleClient: OAuth2Client;

  constructor(
    private readonly usersService: UsersService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly eventEmitter: EventEmitter2,
    private readonly otpService: OtpService,
  ) {
    this.googleClient = new OAuth2Client(
      this.configService.getOrThrow<string>('GOOGLE_CLIENT_ID'),
    );
  }

  async sendRegistrationOtp(email: string): Promise<void> {
    const existingUser = await this.usersService.findByEmail(email);
    if (existingUser) {
      throw new ConflictException('Email already registered');
    }
    await this.otpService.sendOtp(email, 'email_verification');
  }

  sendPasswordResetOtp(email: string): Promise<void> {
    this.eventEmitter.emit(PASSWORD_RESET_REQUEST_EVENT, { email });
    return Promise.resolve();
  }

  @OnEvent(PASSWORD_RESET_REQUEST_EVENT, { async: true })
  async handlePasswordResetRequest(payload: { email: string }): Promise<void> {
    const { email } = payload;
    const existingUser = await this.usersService.findByEmail(email);
    if (!existingUser) {
      // Silently return to prevent email enumeration attacks.
      this.logger.warn(
        `Password reset requested for non-existent email: ${email}`,
      );
      return;
    }
    try {
      await this.otpService.sendOtp(email, 'password_reset');
    } catch (err: unknown) {
      const errorMessage = err instanceof Error ? err.message : 'Unknown error';
      const errorStack = err instanceof Error ? err.stack : undefined;
      this.logger.error(
        `Failed to send password reset OTP for ${email}: ${errorMessage}`,
        errorStack,
      );
    }
  }

  async register(
    dto: RegisterDto,
    meta: ClientMetaDto,
  ): Promise<{
    access_token: string;
    user: { id: string; email: string; username: string };
    isNewUser: boolean;
  }> {
    // Verify the email verification token
    const verifiedEmail = this.verifyEmailToken(dto.emailVerificationToken);

    if (verifiedEmail !== dto.email) {
      throw new BadRequestException(
        'Verification token does not match the provided email',
      );
    }

    // Check for duplicate email (race condition safety)
    const existingUser = await this.usersService.findByEmail(dto.email);

    if (existingUser) {
      throw new ConflictException('Email already registered');
    }

    // Check for duplicate username
    const existingUsername = await this.usersService.findByUsername(
      dto.username,
    );

    if (existingUsername) {
      throw new ConflictException('Username already taken');
    }

    const passwordHash = await bcrypt.hash(dto.password, BCRYPT_SALT_ROUNDS);
    const user = await this.usersService.create(
      dto.email,
      dto.username,
      passwordHash,
      true,
    );

    this.eventEmitter.emit(
      AUDIT_LOG_EVENT,
      createAuditLogEvent(user.id, AuditAction.REGISTER, meta, {
        email: dto.email,
      }),
    );

    return this.generateToken(user, true);
  }

  async login(
    dto: LoginDto,
    meta: ClientMetaDto,
  ): Promise<{
    access_token: string;
    user: { id: string; email: string; username: string };
    isNewUser: boolean;
  }> {
    let user: User | null;

    if (dto.identifier.includes('@')) {
      user = await this.usersService.findByEmail(dto.identifier);
    } else {
      user = await this.usersService.findByUsername(dto.identifier);
    }

    if (!user || !user.passwordHash) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const isPasswordValid = await bcrypt.compare(
      dto.password,
      user.passwordHash,
    );

    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid credentials');
    }

    this.eventEmitter.emit(
      AUDIT_LOG_EVENT,
      createAuditLogEvent(user.id, AuditAction.LOGIN, meta, {
        identifier: dto.identifier,
      }),
    );

    return this.generateToken(user, false);
  }

  async googleAuth(
    idToken: string,
    meta: ClientMetaDto,
  ): Promise<{
    access_token: string;
    user: { id: string; email: string; username: string };
    isNewUser: boolean;
  }> {
    try {
      const {
        email,
        sub: googleId,
        given_name,
      } = await this.verifyGoogleIdToken(idToken);

      // 1. Check if user exists by googleId
      let user = await this.usersService.findByGoogleId(googleId);
      let isNewUser = false;

      // 2. If not, check if user exists by email (Account Linking)
      if (!user) {
        user = await this.usersService.findByEmail(email);
        if (user) {
          // Implicit linking: update googleId and set isEmailVerified = true
          user = await this.usersService.linkGoogleAccount(user.id, googleId);
        } else {
          // 3. User does not exist at all, register new OAuth user
          const uniqueUsername = await this.generateUniqueUsername(
            given_name || email.split('@')[0],
          );
          user = await this.usersService.createOAuthUser(
            email,
            uniqueUsername,
            googleId,
            true, // Google verifies the email
          );
          isNewUser = true;
        }
      }

      this.eventEmitter.emit(
        AUDIT_LOG_EVENT,
        createAuditLogEvent(user.id, AuditAction.GOOGLE_AUTH, meta, {
          email,
          isNewUser: !user.googleId,
        }),
      );

      // Return the new session
      return this.generateToken(user, isNewUser);
    } catch (error) {
      if (error instanceof UnauthorizedException) {
        throw error;
      }
      throw new UnauthorizedException('Failed to authenticate with Google');
    }
  }

  private async generateUniqueUsername(base: string): Promise<string> {
    // Sanitize base: remove non-alphanumeric chars
    const sanitizedBase = base.replace(/[^a-zA-Z0-9]/g, '').toLowerCase();

    // Ensure it's at least 3 chars (for our validation logic)
    let username = sanitizedBase.padEnd(3, 'x');

    // Truncate to leave room for the random suffix if needed
    username = username.slice(0, 20);

    let isUnique = false;
    let finalUsername = username;

    while (!isUnique) {
      const existing = await this.usersService.findByUsername(finalUsername);
      if (!existing) {
        isUnique = true;
      } else {
        const randomSuffix = crypto.randomInt(1000, 9999).toString();
        finalUsername = `${username}_${randomSuffix}`;
      }
    }

    return finalUsername;
  }

  async resetPassword(
    dto: ResetPasswordDto,
    meta: ClientMetaDto,
  ): Promise<void> {
    let payload: OtpVerificationPayload;

    try {
      payload = this.jwtService.verify<OtpVerificationPayload>(dto.resetToken);
    } catch {
      throw new BadRequestException('Invalid or expired reset token');
    }

    if (payload.purpose !== 'password_reset') {
      throw new BadRequestException('Invalid reset token');
    }

    const email = payload.email;

    if (!email || email !== dto.email) {
      throw new BadRequestException(
        'Reset token does not match the provided email',
      );
    }

    const user = await this.usersService.findByEmail(email);
    if (!user) {
      throw new BadRequestException('User does not exist');
    }

    const passwordHash = await bcrypt.hash(dto.newPassword, BCRYPT_SALT_ROUNDS);
    await this.usersService.updatePassword(user.id, passwordHash);

    this.eventEmitter.emit(
      AUDIT_LOG_EVENT,
      createAuditLogEvent(user.id, AuditAction.PASSWORD_RESET, meta, {
        email,
      }),
    );
  }

  async logoutAll(userId: string, meta: ClientMetaDto): Promise<void> {
    await this.usersService.incrementTokenVersion(userId);

    this.eventEmitter.emit(
      AUDIT_LOG_EVENT,
      createAuditLogEvent(userId, AuditAction.LOGOUT_ALL, meta),
    );
  }

  async verifyGoogleIdToken(
    idToken: string,
  ): Promise<{ email: string; sub: string; given_name?: string }> {
    try {
      const ticket = await this.googleClient.verifyIdToken({
        idToken,
        audience: this.configService.getOrThrow<string>('GOOGLE_CLIENT_ID'),
      });
      const payload = ticket.getPayload();

      if (!payload || !payload.email || !payload.sub) {
        throw new UnauthorizedException('Invalid Google token payload');
      }

      return {
        email: payload.email,
        sub: payload.sub,
        given_name: payload.given_name,
      };
    } catch (error) {
      if (error instanceof UnauthorizedException) {
        throw error;
      }
      throw new UnauthorizedException('Invalid Google token');
    }
  }

  private verifyEmailToken(token: string): string {
    try {
      const payload = this.jwtService.verify<OtpVerificationPayload>(token);

      if (payload.purpose !== 'email_verification') {
        throw new BadRequestException('Invalid verification token');
      }

      return payload.email!;
    } catch {
      throw new BadRequestException(
        'Invalid or expired email verification token',
      );
    }
  }

  private generateToken(
    user: {
      id: string;
      email: string;
      username: string;
      tokenVersion: number;
    },
    isNewUser: boolean,
  ): {
    access_token: string;
    user: { id: string; email: string; username: string };
    isNewUser: boolean;
  } {
    const payload: JwtPayload = {
      sub: user.id,
      tokenVersion: user.tokenVersion,
    };

    return {
      access_token: this.jwtService.sign(payload),
      user: {
        id: user.id,
        email: user.email,
        username: user.username,
      },
      isNewUser,
    };
  }
}
