import { Global, Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { ThrottlerStorageRedisService } from '@nest-lab/throttler-storage-redis';

@Global()
@Module({
  imports: [
    ThrottlerModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        throttlers: [
          {
            name: 'default',
            ttl:
              process.env.NODE_ENV === 'test'
                ? 1000
                : configService.get<number>('RATE_LIMIT_DEFAULT_TTL_MS', 60000),
            limit:
              process.env.NODE_ENV === 'test'
                ? 999999
                : configService.get<number>('RATE_LIMIT_DEFAULT_LIMIT', 100),
          },
        ],
        storage: new ThrottlerStorageRedisService({
          host: configService.get<string>('REDIS_HOST', 'redis'),
          port: configService.get<number>('REDIS_PORT', 6379),
        }),
      }),
    }),
  ],
  exports: [ThrottlerModule],
})
export class GlobalThrottlerModule {}
