import {
  Injectable,
  ConflictException,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { UsersService } from '../users/users.service';
import type { RegisterDto } from './dto/register.dto';
import type { LoginDto } from './dto/login.dto';
import type { JwtPayload } from './interfaces/jwt-payload.interface';

const BCRYPT_SALT_ROUNDS = 10;

@Injectable()
export class AuthService {
  constructor(
    private readonly usersService: UsersService,
    private readonly jwtService: JwtService,
  ) {}

  async register(
    dto: RegisterDto,
  ): Promise<{ access_token: string }> {
    const existingUser = await this.usersService.findByEmail(dto.email);

    if (existingUser) {
      throw new ConflictException('Email already registered');
    }

    const existingUsername = await this.usersService.findByUsername(dto.username);

    if (existingUsername) {
      throw new ConflictException('Username already registered');
    }

    const passwordHash = await bcrypt.hash(dto.password, BCRYPT_SALT_ROUNDS);
    const user = await this.usersService.create(
      dto.email,
      dto.username,
      passwordHash,
    );

    return this.generateToken(user.id, user.email);
  }

  async login(
    dto: LoginDto,
  ): Promise<{ access_token: string }> {
    const user = await this.usersService.findByEmail(dto.email);

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
