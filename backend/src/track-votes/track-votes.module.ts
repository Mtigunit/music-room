import { Module } from '@nestjs/common';
import { TrackVotesGateway } from './track-votes.gateway';
import { TrackVotesRepository } from './track-votes.repository';
import { TrackVotesService } from './track-votes.service';
import { WebsocketsModule } from '../websockets/websockets.module';
import { RedisModule } from '../redis/redis.module';

@Module({
  imports: [WebsocketsModule, RedisModule],
  providers: [TrackVotesGateway, TrackVotesService, TrackVotesRepository],
})
export class TrackVotesModule {}
