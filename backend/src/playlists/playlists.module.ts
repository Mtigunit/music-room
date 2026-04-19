import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { PlaylistsService } from './playlists.service';
import { PlaylistsController } from './playlists.controller';
import { PlaylistsRepository } from './playlists.repository';

@Module({
  imports: [PrismaModule],
  controllers: [PlaylistsController],
  providers: [PlaylistsService, PlaylistsRepository],
})
export class PlaylistsModule {}
