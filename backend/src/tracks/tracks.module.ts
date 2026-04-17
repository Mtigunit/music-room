import { Module } from '@nestjs/common';
import { TracksController } from './tracks.controller';
import { YoutubeService } from './youtube.service';

@Module({
  controllers: [TracksController],
  providers: [YoutubeService],
  exports: [YoutubeService],
})
export class TracksModule {}
