import { Module } from '@nestjs/common';
import { VotesService } from './votes.service';

@Module({
  providers: [VotesService],
})
export class VotesModule {}
