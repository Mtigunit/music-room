import { Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import type { Socket } from 'socket.io';
import { UsersService } from '../users/users.service';
import type { JwtPayload } from '../auth/interfaces/jwt-payload.interface';

export interface SocketUser {
  id: string;
  email: string;
}

interface SocketData {
  user?: SocketUser;
}

@Injectable()
export class SocketAuthService {
  constructor(
    private readonly jwtService: JwtService,
    private readonly usersService: UsersService,
  ) {}

  async validateToken(token: string | null): Promise<SocketUser | null> {
    const payload = this.verifyToken(token);
    if (!payload) {
      return null;
    }

    const user = await this.usersService.findById(payload.sub);
    if (!user) {
      return null;
    }

    return { id: user.id, email: user.email };
  }

  private verifyToken(token: string | null): JwtPayload | null {
    if (!token || token.trim().length === 0) {
      return null;
    }

    try {
      return this.jwtService.verify<JwtPayload>(token);
    } catch {
      return null;
    }
  }

  setUser(client: Socket, user: SocketUser): void {
    const data = client.data as SocketData;
    data.user = user;
  }

  getUser(client: Socket): SocketUser | null {
    const data = client.data as SocketData;
    return data.user ?? null;
  }
}
