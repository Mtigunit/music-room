import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { EventEmitterModule } from '@nestjs/event-emitter';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { ThrottlerGuard } from '@nestjs/throttler';
import { ServeStaticModule } from '@nestjs/serve-static';
import { join } from 'path';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AppRepository } from './app.repository';
import { AuditLogModule } from './audit-log/audit-log.module';
import { FollowsModule } from './follows/follows.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { EventsModule } from './events/events.module';
import { PlaylistsModule } from './playlists/playlists.module';
import { validate } from './config/env.validation';
import { PrismaModule } from './prisma/prisma.module';
import { RedisModule } from './redis/redis.module';
import { WebsocketsModule } from './websockets/websockets.module';
import { TrackVotesModule } from './track-votes/track-votes.module';
import { TracksModule } from './tracks/tracks.module';
import { RequestLoggerMiddleware } from './common/middleware/request-logger.middleware';
import { BullModule } from '@nestjs/bullmq';
import { GlobalThrottlerModule } from './common/throttler/global-throttler.module';
import { NotificationsModule } from './notifications/notifications.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validate,
    }),
    GlobalThrottlerModule,
    EventEmitterModule.forRoot(),
    ServeStaticModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => {
        const uploadPath = configService.get<string>('UPLOAD_PATH', 'uploads');
        return [
          {
            rootPath: join(process.cwd(), uploadPath),
            serveRoot: '/uploads',
          },
        ];
      },
    }),
    AuditLogModule,
    AuthModule,
    UsersModule,
    EventsModule,
    PlaylistsModule,
    PrismaModule,
    RedisModule,
    WebsocketsModule,
    TrackVotesModule,
    TracksModule,
    FollowsModule,
    NotificationsModule,
    BullModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        connection: {
          host: configService.get<string>('REDIS_HOST', 'redis'),
          port: configService.get<number>('REDIS_PORT', 6379),
        },
      }),
    }),
  ],
  controllers: [AppController],
  providers: [
    AppService,
    AppRepository,
    { provide: APP_GUARD, useClass: ThrottlerGuard },
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(RequestLoggerMiddleware).forRoutes('*');
  }
}
