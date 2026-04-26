import {
  Injectable,
  BadRequestException,
  ConflictException,
  Logger,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { randomInt, timingSafeEqual } from 'crypto';
import { RedisService } from '../redis/redis.service';
import { MailService } from '../mail/mail.service';
import { UsersService } from '../users/users.service';

const OTP_LENGTH = 6;
const OTP_TTL_SECONDS = 300; // 5 minutes
const RATE_LIMIT_MAX = 5;
const RATE_LIMIT_WINDOW_SECONDS = 900; // 15 minutes
const MAX_VERIFY_ATTEMPTS = 5;
const VERIFICATION_TOKEN_EXPIRY = '10m';

export type OtpPurpose = 'email_verification' | 'password_reset';

interface OtpVerificationPayload {
  email: string;
  purpose: OtpPurpose;
}

@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);

  constructor(
    private readonly redisService: RedisService,
    private readonly mailService: MailService,
    private readonly usersService: UsersService,
    private readonly jwtService: JwtService,
  ) {}

  async sendOtp(
    email: string,
    purpose: OtpPurpose = 'email_verification',
  ): Promise<void> {
    const existingUser = await this.usersService.findByEmail(email);

    if (purpose === 'email_verification' && existingUser) {
      throw new ConflictException('Email already registered');
    }

    if (purpose === 'password_reset' && !existingUser) {
      // Silently return to prevent email enumeration attacks.
      // The caller always receives a generic success message.
      this.logger.warn(
        `Password reset requested for non-existent email: ${email}`,
      );
      return;
    }

    // Rate limiting
    const rateLimitKey = `otp:rate:${purpose}:${email}`;
    const redis = this.redisService.getClient();
    const currentCount = await redis.get(rateLimitKey);

    if (currentCount && parseInt(currentCount, 10) >= RATE_LIMIT_MAX) {
      throw new BadRequestException(
        'Too many OTP requests. Please try again later.',
      );
    }

    // Generate OTP
    const code = this.generateOtp();

    // Store OTP in Redis
    const otpKey = `otp:${purpose}:${email}`;
    const attemptsKey = `otp:attempts:${purpose}:${email}`;
    await redis.set(otpKey, code, 'EX', OTP_TTL_SECONDS);
    await redis.set(attemptsKey, '0', 'EX', OTP_TTL_SECONDS);

    // Increment rate limit counter
    const exists = await redis.exists(rateLimitKey);
    await redis.incr(rateLimitKey);

    if (!exists) {
      await redis.expire(rateLimitKey, RATE_LIMIT_WINDOW_SECONDS);
    }

    // Send email
    await this.mailService.sendOtpEmail(email, code, purpose);
    this.logger.log(`OTP sent to ${email} for ${purpose}`);
  }

  async verifyOtp(
    email: string,
    code: string,
    purpose: OtpPurpose = 'email_verification',
  ): Promise<{ token: string }> {
    const redis = this.redisService.getClient();
    const otpKey = `otp:${purpose}:${email}`;
    const attemptsKey = `otp:attempts:${purpose}:${email}`;

    // Check brute-force attempts
    const attempts = await redis.get(attemptsKey);

    if (attempts && parseInt(attempts, 10) >= MAX_VERIFY_ATTEMPTS) {
      // Delete the OTP — force user to request a new one
      await redis.del(otpKey, attemptsKey);
      throw new BadRequestException(
        'Too many failed attempts. Please request a new OTP.',
      );
    }

    const storedCode = await redis.get(otpKey);

    if (!storedCode) {
      throw new BadRequestException('OTP expired or not found');
    }

    // Timing-safe comparison to prevent timing attacks
    if (!this.safeCompare(code, storedCode)) {
      await redis.incr(attemptsKey);
      throw new BadRequestException('Invalid OTP');
    }

    // OTP is valid — delete it (single use)
    await redis.del(otpKey, attemptsKey);

    // Generate a short-lived verification token
    const payload: OtpVerificationPayload = {
      email,
      purpose,
    };

    const token = this.jwtService.sign(payload, {
      expiresIn: VERIFICATION_TOKEN_EXPIRY,
    });

    return { token };
  }

  private generateOtp(): string {
    // Generate a cryptographically random 6-digit code
    const max = Math.pow(10, OTP_LENGTH);
    const code = randomInt(0, max);
    return code.toString().padStart(OTP_LENGTH, '0');
  }

  private safeCompare(a: string, b: string): boolean {
    if (a.length !== b.length) {
      return false;
    }

    return timingSafeEqual(Buffer.from(a), Buffer.from(b));
  }
}
