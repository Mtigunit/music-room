import { Injectable, Logger } from '@nestjs/common';
import type { Socket } from 'socket.io';
import { SocketAuthService } from './socket-auth.service';

@Injectable()
export class HandshakeMiddleware {
  private readonly logger = new Logger(HandshakeMiddleware.name);

  constructor(private readonly socketAuthService: SocketAuthService) {}

  use() {
    return (socket: Socket, next: (err?: any) => void) => {
      void (async () => {
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
      })();
    };
  }
}
