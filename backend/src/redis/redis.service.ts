import {
  Injectable,
  OnModuleInit,
  OnModuleDestroy,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Redis } from 'ioredis';

@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private redisClient!: Redis;
  private readonly logger = new Logger(RedisService.name);

  constructor(private readonly configService: ConfigService) {}

  onModuleInit() {
    const host = this.configService.get<string>('REDIS_HOST', 'redis');
    const port = this.configService.get<number>('REDIS_PORT', 6379);

    this.redisClient = new Redis({
      host,
      port,
    });

    this.redisClient.on('connect', () =>
      this.logger.log('Successfully connected to Redis'),
    );
    this.redisClient.on('error', (err) =>
      this.logger.error('Redis connection error', err),
    );
  }

  async onModuleDestroy() {
    if (this.redisClient) {
      try {
        await this.redisClient.quit(); // Graceful shutdown, flushes pending commands
        this.logger.log('Redis connection closed gracefully');
      } catch (err) {
        this.logger.warn(
          'Error during Redis shutdown',
          err instanceof Error ? err.message : String(err),
        );
      }
    }
  }

  // Expose the client so you can use it in other services
  getClient(): Redis {
    return this.redisClient;
  }
}
