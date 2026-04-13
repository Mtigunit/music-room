import {
  Injectable,
  ConflictException,
  UnauthorizedException,
  BadRequestException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { UsersService } from '../users/users.service';
import type { RegisterDto } from './dto/register.dto';
import type { LoginDto } from './dto/login.dto';
import type { JwtPayload } from './interfaces/jwt-payload.interface';
import type { User } from '@prisma/client';

const BCRYPT_SALT_ROUNDS = 10;

interface EmailVerificationPayload {
  email: string;
  purpose: string;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly usersService: UsersService,
    private readonly jwtService: JwtService,
  ) {}

  async register(dto: RegisterDto): Promise<{ access_token: string }> {
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

    return this.generateToken(user.id, user.email);
  }

  async login(dto: LoginDto): Promise<{ access_token: string }> {
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

    return this.generateToken(user.id, user.email);
  }

  private verifyEmailToken(token: string): string {
    try {
      const payload = this.jwtService.verify<EmailVerificationPayload>(token);

      if (payload.purpose !== 'email_verification') {
        throw new BadRequestException('Invalid verification token');
      }

      return payload.email;
    } catch {
      throw new BadRequestException(
        'Invalid or expired email verification token',
      );
    }
  }

  private generateToken(
    userId: string,
    email: string,
  ): { access_token: string } {
    const payload: JwtPayload = { sub: userId, email };

    return {
      access_token: this.jwtService.sign(payload),
    };
  }
}
