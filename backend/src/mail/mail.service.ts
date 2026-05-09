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
    purpose:
      | 'email_verification'
      | 'password_reset'
      | 'email_update' = 'email_verification',
  ): Promise<void> {
    if (this.isDev) {
      this.logger.log(`[DEV] ${purpose} OTP for ${to}: ${code}`);
      return;
    }

    const subjectMap = {
      password_reset: 'Music Room — Password Reset',
      email_verification: 'Music Room — Verify your email',
      email_update: 'Music Room — Update your email',
    };

    const titleMap = {
      password_reset: 'Password Reset',
      email_verification: 'Email Verification',
      email_update: 'Confirm Email Update',
    };

    const subject = subjectMap[purpose];
    const title = titleMap[purpose];

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

  async sendSecurityAlert(to: string, newEmail: string): Promise<void> {
    if (this.isDev) {
      this.logger.log(
        `[DEV] Security alert for ${to}: Email change requested to ${newEmail}`,
      );
      return;
    }

    try {
      await this.transporter!.sendMail({
        from: this.fromAddress,
        to,
        subject: 'Music Room — Security Alert: Email Change Requested',
        html: `
          <h2>Security Alert</h2>
          <p>We received a request to change the email address for your Music Room account to <strong>${newEmail}</strong>.</p>
          <p>If you made this request, please use the OTP sent to your new email to confirm the change.</p>
          <hr />
          <p style="color: #666; font-size: 12px;">If you did NOT make this request, please secure your account immediately by changing your password.</p>
        `,
      });
    } catch (error) {
      this.logger.error(`Failed to send security alert email to ${to}:`, error);
      // We don't throw here to avoid blocking the request if the alert fails,
      // but we log it for auditing.
    }
  }
}
