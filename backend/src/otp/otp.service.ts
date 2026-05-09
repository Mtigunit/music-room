import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { randomInt, timingSafeEqual } from 'crypto';
import { RedisService } from '../redis/redis.service';
import { MailService } from '../mail/mail.service';

const OTP_LENGTH = 6;
const OTP_TTL_SECONDS = 300; // 5 minutes
const RATE_LIMIT_MAX = 5;
const RATE_LIMIT_WINDOW_SECONDS = 900; // 15 minutes
const MAX_VERIFY_ATTEMPTS = 5;
const VERIFICATION_TOKEN_EXPIRY = '10m';

export type OtpPurpose =
  | 'email_verification'
  | 'password_reset'
  | 'email_update';

export interface OtpData {
  newEmail?: string;
  [key: string]: any;
}

export interface OtpVerificationPayload {
  email?: string;
  userId?: string;
  purpose: OtpPurpose;
  data?: OtpData;
}

@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);

  constructor(
    private readonly redisService: RedisService,
    private readonly mailService: MailService,
    private readonly jwtService: JwtService,
  ) {}

  async sendOtp(
    identifier: string,
    purpose: OtpPurpose = 'email_verification',
    targetEmail?: string,
    data?: OtpData,
  ): Promise<void> {
    // Rate limiting
    const rateLimitKey = `otp:rate:${purpose}:${identifier}`;
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
    const otpKey = `otp:${purpose}:${identifier}`;
    const attemptsKey = `otp:attempts:${purpose}:${identifier}`;
    const dataKey = `otp:data:${purpose}:${identifier}`;

    await redis.set(otpKey, code, 'EX', OTP_TTL_SECONDS);
    await redis.set(attemptsKey, '0', 'EX', OTP_TTL_SECONDS);

    if (data) {
      await redis.set(dataKey, JSON.stringify(data), 'EX', OTP_TTL_SECONDS);
    }

    // Increment rate limit counter
    const exists = await redis.exists(rateLimitKey);
    await redis.incr(rateLimitKey);

    if (!exists) {
      await redis.expire(rateLimitKey, RATE_LIMIT_WINDOW_SECONDS);
    }

    // Send email
    const emailToUse = targetEmail || identifier;
    await this.mailService.sendOtpEmail(emailToUse, code, purpose);
    this.logger.log(
      `OTP sent to ${emailToUse} for ${purpose} (ID: ${identifier})`,
    );
  }

  async verifyOtp(
    identifier: string,
    code: string,
    purpose: OtpPurpose = 'email_verification',
  ): Promise<{ token: string; data?: OtpData }> {
    const redis = this.redisService.getClient();
    const otpKey = `otp:${purpose}:${identifier}`;
    const attemptsKey = `otp:attempts:${purpose}:${identifier}`;
    const dataKey = `otp:data:${purpose}:${identifier}`;

    // Check brute-force attempts
    const attempts = await redis.get(attemptsKey);

    if (attempts && parseInt(attempts, 10) >= MAX_VERIFY_ATTEMPTS) {
      // Delete the OTP — force user to request a new one
      await redis.del(otpKey, attemptsKey, dataKey);
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

    // Retrieve data if exists
    const storedData = await redis.get(dataKey);
    const data: OtpData | undefined = storedData
      ? (JSON.parse(storedData) as OtpData)
      : undefined;

    // OTP is valid — delete it (single use)
    await redis.del(otpKey, attemptsKey, dataKey);

    // Generate a short-lived verification token
    const payload: OtpVerificationPayload = {
      purpose,
      data,
      ...(purpose === 'email_update'
        ? { userId: identifier }
        : { email: identifier }),
    };

    const token = this.jwtService.sign(payload, {
      expiresIn: VERIFICATION_TOKEN_EXPIRY,
    });

    return { token, data };
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
