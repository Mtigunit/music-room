import {
  CanActivate,
  ExecutionContext,
  Injectable,
  Logger,
  Optional,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectThrottlerStorage, ThrottlerStorage } from '@nestjs/throttler';
import { WsException } from '@nestjs/websockets';
import type { Socket } from 'socket.io';
import { SocketAuthService } from '../socket-auth.service';

/**
 * WebSocket rate-limiting guard.
 *
 * Enforces a per-user limit of 30 messages per 60 seconds across all
 * subscribed gateway events (configurable via env).
 *
 * On limit breach, a `rate:limit` exception is thrown.
 */
@Injectable()
export class WsThrottlerGuard implements CanActivate {
  private readonly logger = new Logger(WsThrottlerGuard.name);

  constructor(
    @Optional()
    @InjectThrottlerStorage()
    private readonly throttlerStorage: ThrottlerStorage,
    private readonly socketAuthService: SocketAuthService,
    private readonly configService: ConfigService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    if (!this.throttlerStorage) {
      throw new Error('ThrottlerStorage is undefined! DI failed.');
    }

    const client = context.switchToWs().getClient<Socket>();
    const user = this.socketAuthService.getUser(client);

    const key = `ws-throttle:${user!.id}`;

    const ttlMs = this.configService.get<number>('RATE_LIMIT_WS_TTL_MS', 60000);
    const limit = this.configService.get<number>('RATE_LIMIT_WS_LIMIT', 30);

    const { totalHits } = await this.throttlerStorage.increment(
      key,
      ttlMs,
      limit,
      ttlMs,
      'default',
    );

    if (totalHits > limit) {
      this.logger.warn(
        `WS rate limit exceeded: userId=${user!.id} hits=${totalHits}`,
      );
      throw new WsException({
        status: 'error',
        event: 'rate:limit',
        message: 'Too many requests. Please slow down.',
        retryAfterMs: ttlMs,
      });
    }

    return true;
  }
}
