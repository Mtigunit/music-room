import {
  CanActivate,
  ExecutionContext,
  Injectable,
  Logger,
} from '@nestjs/common';
import type { Socket } from 'socket.io';
import { SocketAuthService } from '../socket-auth.service';

@Injectable()
export class WsAuthGuard implements CanActivate {
  private readonly logger = new Logger(WsAuthGuard.name);

  constructor(private readonly socketAuthService: SocketAuthService) {}

  canActivate(context: ExecutionContext): boolean {
    const client = context.switchToWs().getClient<Socket>();
    const user = this.socketAuthService.getUser(client);

    if (!user) {
      this.logger.warn(`Unauthorized socket event: id=${client.id}`);
      client.disconnect(true);
      return false;
    }

    return true;
  }
}
