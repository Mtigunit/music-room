import { Injectable, Logger } from '@nestjs/common';
import type { Socket } from 'socket.io';
import { SocketAuthService } from './socket-auth.service';

@Injectable()
export class HandshakeMiddleware {
  private readonly logger = new Logger(HandshakeMiddleware.name);

  constructor(private readonly socketAuthService: SocketAuthService) {}

  use() {
    return (socket: Socket, next: (err?: Error) => void) => {
      void this.validateHandshake(socket, next);
    };
  }

  private async validateHandshake(
    socket: Socket,
    next: (err?: Error) => void,
  ): Promise<void> {
    try {
      const auth = socket.handshake.auth as { token?: unknown } | undefined;
      const token = typeof auth?.token === 'string' ? auth.token : null;

      const user = await this.socketAuthService.validateToken(token);
      if (!user) {
        this.logger.warn(`Handshake unauthorized socket id=${socket.id}`);
        next(new Error('unauthorized'));
        return;
      }

      this.socketAuthService.setUser(socket, user);
      next();
    } catch (error: unknown) {
      const message =
        error instanceof Error ? error.message : 'Unknown handshake error';
      const stack = error instanceof Error ? error.stack : undefined;

      this.logger.error(
        `Handshake failed: socket id=${socket.id} ${message}`,
        stack,
      );

      next(new Error('unauthorized'));
    }
  }
}
