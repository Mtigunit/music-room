import { Injectable } from '@nestjs/common';
import { CreatePlaylistDto } from './dto/create-playlist.dto';
import { UpdatePlaylistDto } from './dto/update-playlist.dto';
import { PlaylistsRepository } from './playlists.repository';

@Injectable()
export class PlaylistsService {
  constructor(private readonly playlistsRepository: PlaylistsRepository) {}

  create(createPlaylistDto: CreatePlaylistDto) {
    return this.playlistsRepository.create(createPlaylistDto);
  }

  findAll() {
    return this.playlistsRepository.findAll();
  }

  findOne(id: number) {
    return this.playlistsRepository.findOne(id);
  }

  update(id: number, updatePlaylistDto: UpdatePlaylistDto) {
    return this.playlistsRepository.update(id, updatePlaylistDto);
  }

  remove(id: number) {
    return this.playlistsRepository.remove(id);
  }
}
