import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AppRepository } from './app.repository';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { EventsModule } from './events/events.module';
import { PlaylistsModule } from './playlists/playlists.module';
import { validate } from './config/env.validation';
import { PrismaModule } from './prisma/prisma.module';
import { RedisModule } from './redis/redis.module';
import { WebsocketsModule } from './websockets/websockets.module';
import { VotesModule } from './votes/votes.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validate,
    }),
    AuthModule,
    UsersModule,
    EventsModule,
    PlaylistsModule,
    PrismaModule,
    RedisModule,
    WebsocketsModule,
    VotesModule,
  ],
  controllers: [AppController],
  providers: [AppService, AppRepository],
})
export class AppModule {}
