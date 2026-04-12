import { Module } from '@nestjs/common';
import { PlaylistsService } from './playlists.service';
import { PlaylistsController } from './playlists.controller';
import { PlaylistsRepository } from './playlists.repository';

@Module({
  controllers: [PlaylistsController],
  providers: [PlaylistsService, PlaylistsRepository],
})
export class PlaylistsModule {}
