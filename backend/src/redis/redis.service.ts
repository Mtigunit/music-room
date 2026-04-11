import { Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Redis } from 'ioredis';

@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private redisClient!: Redis;

  constructor(private readonly configService: ConfigService) {}

  onModuleInit() {
    const host = this.configService.get<string>('REDIS_HOST', 'redis');
    const port = this.configService.get<number>('REDIS_PORT', 6379);

    this.redisClient = new Redis({
      host,
      port,
    });

    this.redisClient.on('connect', () =>
      console.log('Successfully connected to Redis'),
    );
    this.redisClient.on('error', (err) =>
      console.error('Redis connection error:', err),
    );
  }

  onModuleDestroy() {
    this.redisClient.disconnect();
  }

  // Expose the client so you can use it in other services
  getClient(): Redis {
    return this.redisClient;
  }
}
