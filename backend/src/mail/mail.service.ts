import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';
import type { Transporter } from 'nodemailer';

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private transporter: Transporter | null = null;
  private readonly isDev: boolean;
  private readonly fromAddress: string;

  constructor(private readonly configService: ConfigService) {
    this.isDev = !this.configService.get('SMTP_HOST');
    this.fromAddress = this.configService.get<string>(
      'SMTP_FROM',
      'noreply@music-room.com',
    );

    if (!this.isDev) {
      this.transporter = nodemailer.createTransport({
        host: this.configService.getOrThrow<string>('SMTP_HOST'),
        port: this.configService.get<number>('SMTP_PORT', 587),
        secure: false,
        auth: {
          user: this.configService.getOrThrow<string>('SMTP_USER'),
          pass: this.configService.getOrThrow<string>('SMTP_PASS'),
        },
      });
    }
  }

  async sendOtpEmail(
    to: string,
    code: string,
    purpose: 'email_verification' | 'password_reset' = 'email_verification',
  ): Promise<void> {
    if (this.isDev) {
      this.logger.log(`[DEV] ${purpose} OTP for ${to}: ${code}`);
      return;
    }

    const subject =
      purpose === 'password_reset'
        ? 'Music Room — Password Reset'
        : 'Music Room — Verify your email';

    const title =
      purpose === 'password_reset' ? 'Password Reset' : 'Email Verification';

    try {
      await this.transporter!.sendMail({
        from: this.fromAddress,
        to,
        subject,
        html: `
          <h2>${title}</h2>
          <p>Your code is:</p>
          <h1 style="letter-spacing: 8px; font-size: 36px; text-align: center;">${code}</h1>
          <p>This code expires in 5 minutes.</p>
          <p>If you didn't request this, please ignore this email.</p>
        `,
      });
    } catch (error) {
      this.logger.error(`Failed to send OTP email to ${to}:`, error);
      throw new Error('Failed to send OTP email');
    }
  }
}
