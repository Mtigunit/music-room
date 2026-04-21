import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { PlaylistsService } from './playlists.service';
import { PlaylistsController } from './playlists.controller';
import { PlaylistsRepository } from './playlists.repository';
import { PlaylistsGateway } from './playlists.gateway';
import { WebsocketsModule } from '../websockets/websockets.module';
import { TracksModule } from '../tracks/tracks.module';

@Module({
  imports: [PrismaModule, WebsocketsModule, TracksModule],
  controllers: [PlaylistsController],
  providers: [PlaylistsService, PlaylistsRepository, PlaylistsGateway],
})
export class PlaylistsModule {}
