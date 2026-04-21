import {
  ForbiddenException,
  Injectable,
  NotFoundException,
  BadRequestException,
  ConflictException,
} from '@nestjs/common';
import { PlaylistsGateway } from './playlists.gateway';
import { CreatePlaylistDto } from './dto/create-playlist.dto';
import { UpdatePlaylistDto } from './dto/update-playlist.dto';
import { PlaylistsRepository } from './playlists.repository';
import { PaginationDto } from '../common/dto/pagination.dto';
import { PlaylistAuthData } from './interfaces/playlist-auth-data.interface';
import { PlaylistEditLicense, Prisma, Tags, Visibility } from '@prisma/client';
import { YoutubeService } from '../tracks/youtube.service';

@Injectable()
export class PlaylistsService {
  constructor(
    private readonly playlistsRepository: PlaylistsRepository,
    private readonly playlistsGateway: PlaylistsGateway,
    private readonly youtubeService: YoutubeService,
  ) {}

  async create(userId: string, createPlaylistDto: CreatePlaylistDto) {
    return this.playlistsRepository.createPlaylist(userId, createPlaylistDto);
  }

  async getUserPlaylists(userId: string, paginationDto: PaginationDto) {
    return this.playlistsRepository.getUserPlaylists(userId, paginationDto);
  }

  async explorePublicPlaylists(
    searchQuery: string | undefined,
    tag: Tags | undefined,
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

    if (playlist.visibility === Visibility.PRIVATE) {
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

  private verifyEditAccess(playlist: PlaylistAuthData, requesterId: string) {
    const isOwner = playlist.ownerId === requesterId;
    const isCollaborator = playlist.collaborators.some(
      (c) => c.userId === requesterId,
    );

    // 1. VISIBILITY FIREWALL: Can the user even see this playlist anymore?
    if (
      playlist.visibility === Visibility.PRIVATE &&
      !isOwner &&
      !isCollaborator
    ) {
      throw new ForbiddenException(
        'You do not have permission to interact with this private playlist',
      );
    }

    // 2. RESTRICTED FIREWALL: Is the playlist locked against non-collaborator edits?
    if (
      playlist.editLicense === PlaylistEditLicense.RESTRICTED &&
      !isOwner &&
      !isCollaborator
    ) {
      throw new ForbiddenException(
        'This playlist is restricted to collaborators only.',
      );
    }
  }

  async addTrackToPlaylist(
    playlistId: string,
    addedById: string,
    providerTrackId: string,
  ) {
    const playlist =
      await this.playlistsRepository.findPlaylistForAuth(playlistId);
    if (!playlist) {
      throw new NotFoundException('Playlist not found');
    }

    // Shared Firewall: Blocks unauthorized interaction with Private or Restricted lists.
    this.verifyEditAccess(playlist, addedById);

    // Constraint 1: Hard Cap
    if (playlist._count.tracks >= 300) {
      throw new BadRequestException(
        'Playlist has reached the maximum capacity of 300 tracks.',
      );
    }

    // Constraint 2: Source of Truth (Spoofing prevention)
    const trackDetails =
      await this.youtubeService.getTrackDetails(providerTrackId);
    if (!trackDetails) {
      throw new NotFoundException('Track not found from provider');
    }

    // Constraint 3: Unique tracks per playlist
    const isDuplicate = await this.playlistsRepository.isTrackInPlaylist(
      playlistId,
      providerTrackId,
    );
    if (isDuplicate) {
      throw new ConflictException('This track is already in the playlist');
    }

    try {
      const result = await this.playlistsRepository.addTrackToPlaylist(
        playlistId,
        addedById,
        trackDetails,
      );

      this.playlistsGateway.server
        ?.to(`playlist_${playlistId}`)
        ?.emit('playlist:track:added', result);

      return result;
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw new ConflictException('This track is already in the playlist');
      }
      throw error;
    }
  }

  async removeTrackFromPlaylist(
    playlistId: string,
    trackId: string,
    requesterId: string,
  ) {
    const playlist =
      await this.playlistsRepository.findPlaylistForAuth(playlistId);
    if (!playlist) {
      throw new NotFoundException('Playlist not found');
    }

    // Shared Firewall: Blocks unauthorized interaction with Private or Restricted lists.
    // Meaning even if they are 'addedById', they cannot delete if they lost broad access.
    this.verifyEditAccess(playlist, requesterId);

    const playlistTrack = await this.playlistsRepository.findPlaylistTrack(
      playlistId,
      trackId,
    );
    if (!playlistTrack) {
      throw new NotFoundException('Track not found in playlist');
    }

    // 3. TRACK OWNERSHIP CHECK: Are you allowed to delete THIS specific track?
    if (
      playlist.ownerId !== requesterId &&
      playlistTrack.addedById !== requesterId
    ) {
      throw new ForbiddenException(
        'You can only remove tracks you added, unless you are the playlist owner',
      );
    }

    const deleted = await this.playlistsRepository.removeTrackFromPlaylist(
      playlistId,
      trackId,
    );

    if (deleted) {
      this.playlistsGateway.server
        ?.to(`playlist_${playlistId}`)
        ?.emit('playlist:track:removed', { trackId });
    }

    return deleted;
  }
}
