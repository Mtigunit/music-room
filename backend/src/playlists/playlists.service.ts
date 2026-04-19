import {
  ForbiddenException,
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { CreatePlaylistDto } from './dto/create-playlist.dto';
import { UpdatePlaylistDto } from './dto/update-playlist.dto';
import { PlaylistsRepository } from './playlists.repository';
import { TrackSearchResultDto } from '../tracks/dto/track-search-result.dto';
import { PaginationDto } from '../common/dto/pagination.dto';
import { PlaylistEditLicense, PlaylistVisibility } from '@prisma/client';

@Injectable()
export class PlaylistsService {
  constructor(private readonly playlistsRepository: PlaylistsRepository) {}

  async create(userId: string, createPlaylistDto: CreatePlaylistDto) {
    return this.playlistsRepository.createPlaylist(userId, createPlaylistDto);
  }

  async getUserPlaylists(userId: string, paginationDto: PaginationDto) {
    return this.playlistsRepository.getUserPlaylists(userId, paginationDto);
  }

  async explorePublicPlaylists(
    searchQuery: string | undefined,
    tag: string | undefined,
    paginationDto: PaginationDto,
  ) {
    return this.playlistsRepository.explorePublicPlaylists(
      searchQuery,
      tag,
      paginationDto,
    );
  }

  async getPlaylistDetails(playlistId: string, requesterId: string) {
    const playlist =
      await this.playlistsRepository.getPlaylistDetails(playlistId);

    if (!playlist) {
      throw new NotFoundException('Playlist not found');
    }

    if (playlist.visibility === PlaylistVisibility.PRIVATE) {
      const isOwner = playlist.ownerId === requesterId;
      const isCollaborator = playlist.collaborators.some(
        (c) => c.userId === requesterId,
      );

      if (!isOwner && !isCollaborator) {
        throw new ForbiddenException(
          'You do not have permission to view this private playlist',
        );
      }
    }

    return playlist;
  }

  async update(
    playlistId: string,
    requesterId: string,
    updatePlaylistDto: UpdatePlaylistDto,
  ) {
    const playlist =
      await this.playlistsRepository.findPlaylistForAuth(playlistId);
    if (!playlist) {
      throw new NotFoundException('Playlist not found');
    }

    if (playlist.ownerId !== requesterId) {
      throw new ForbiddenException('Only the owner can update the playlist');
    }

    return this.playlistsRepository.updatePlaylist(
      playlistId,
      updatePlaylistDto,
    );
  }

  async remove(playlistId: string, requesterId: string) {
    const playlist =
      await this.playlistsRepository.findPlaylistForAuth(playlistId);
    if (!playlist) {
      throw new NotFoundException('Playlist not found');
    }

    if (playlist.ownerId !== requesterId) {
      throw new ForbiddenException('Only the owner can delete the playlist');
    }

    return this.playlistsRepository.deletePlaylist(playlistId);
  }

  async addCollaborator(
    playlistId: string,
    ownerId: string,
    targetUserId: string,
  ) {
    const playlist =
      await this.playlistsRepository.findPlaylistForAuth(playlistId);
    if (!playlist) {
      throw new NotFoundException('Playlist not found');
    }

    if (playlist.ownerId !== ownerId) {
      throw new ForbiddenException(
        'Only the owner can manage collaborators for this playlist',
      );
    }

    const userExists =
      await this.playlistsRepository.checkUserExists(targetUserId);
    if (!userExists) {
      throw new BadRequestException('Target user does not exist');
    }

    // Add collaborator safely via upsert
    return this.playlistsRepository.addCollaborator(playlistId, targetUserId);
  }

  async addTrackToPlaylist(
    playlistId: string,
    addedById: string,
    track: TrackSearchResultDto,
  ) {
    const playlist =
      await this.playlistsRepository.findPlaylistForAuth(playlistId);
    if (!playlist) {
      throw new NotFoundException('Playlist not found');
    }

    const isOwner = playlist.ownerId === addedById;
    const isCollaborator = playlist.collaborators.some(
      (c) => c.userId === addedById,
    );

    if (playlist.visibility === PlaylistVisibility.PRIVATE) {
      if (!isOwner && !isCollaborator) {
        throw new ForbiddenException(
          'You do not have permission to add tracks to this private playlist',
        );
      }
    }

    // Validate editLicense restrictions
    if (playlist.editLicense === PlaylistEditLicense.RESTRICTED) {
      if (!isOwner && !isCollaborator) {
        throw new ForbiddenException(
          'You do not have permission to add tracks to this playlist',
        );
      }
    }

    return this.playlistsRepository.addTrackToPlaylist(
      playlistId,
      addedById,
      track,
    );
  }
}
