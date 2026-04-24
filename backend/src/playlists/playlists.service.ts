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
import {
  OccStaleException,
  TrackNotFoundInTransactionException,
} from './exceptions';
import { TrackSearchResultDto } from '../tracks/dto/track-search-result.dto';

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

    // Ensure non-owners cannot bypass visibility rules.
    if (
      playlist.visibility === Visibility.PRIVATE &&
      !isOwner &&
      !isCollaborator
    ) {
      throw new ForbiddenException(
        'You do not have permission to interact with this private playlist',
      );
    }

    // Ensure non-collaborators cannot bypass restricted edit licenses.
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

    this.verifyEditAccess(playlist, addedById);

    // Enforce playlist size limits
    if (playlist._count.tracks >= 300) {
      throw new BadRequestException(
        'Playlist has reached the maximum capacity of 300 tracks.',
      );
    }

    // Fetch authoritative track metadata (Cache-First Dictionary Strategy)
    let trackDetails: TrackSearchResultDto | null =
      (await this.playlistsRepository.findTrackByProviderId(
        providerTrackId,
      )) as TrackSearchResultDto | null;

    if (!trackDetails) {
      // Not in local dictionary, fetch from provider
      trackDetails = await this.youtubeService.getTrackDetails(providerTrackId);
      if (!trackDetails) {
        throw new NotFoundException('Track not found from provider');
      }
    }

    // Enforce unique tracks per playlist
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
        .to(`playlist_${playlistId}`)
        .emit('playlist:track:added', {
          playlistId,
          newUpdatedAt: result.newUpdatedAt,
          track: result.playlistTrack,
        });

      return {
        newUpdatedAt: result.newUpdatedAt,
        track: result.playlistTrack,
      };
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        const target = error.meta?.target as string[] | undefined;

        if (target?.includes('trackId')) {
          throw new ConflictException('This track is already in the playlist');
        }

        if (target?.includes('providerTrackId')) {
          throw new ConflictException('Please retry adding the track.');
        }
      }
      throw error;
    }
  }

  async removeTrackFromPlaylist(
    playlistId: string,
    playlistTrackId: string,
    requesterId: string,
  ) {
    const playlist =
      await this.playlistsRepository.findPlaylistForAuth(playlistId);
    if (!playlist) {
      throw new NotFoundException('Playlist not found');
    }

    this.verifyEditAccess(playlist, requesterId);

    const playlistTrack = await this.playlistsRepository.findPlaylistTrack(
      playlistId,
      playlistTrackId,
    );
    if (!playlistTrack) {
      throw new NotFoundException('Track not found in playlist');
    }

    // Only the playlist owner or the user who added it can remove the track.
    if (
      playlist.ownerId !== requesterId &&
      playlistTrack.addedById !== requesterId
    ) {
      throw new ForbiddenException(
        'You can only remove tracks you added, unless you are the playlist owner',
      );
    }

    const result = await this.playlistsRepository.removeTrackFromPlaylist(
      playlistId,
      playlistTrackId,
    );

    if (!result || !result.deletedTrack) {
      throw new NotFoundException('Track not found in playlist');
    }

    this.playlistsGateway.server
      .to(`playlist_${playlistId}`)
      .emit('playlist:track:removed', {
        playlistId,
        newUpdatedAt: result.newUpdatedAt,
        deletedTrackId: result.deletedTrack.id,
        updates: result.updates,
      });

    return {
      newUpdatedAt: result.newUpdatedAt,
      deletedTrack: result.deletedTrack,
      updates: result.updates,
    };
  }

  async reorderTrack(
    playlistId: string,
    playlistTrackId: string,
    requesterId: string,
    payload: { newPosition: number; baseUpdatedAt: string },
  ) {
    const playlist =
      await this.playlistsRepository.findPlaylistForAuth(playlistId);

    if (!playlist) {
      throw new NotFoundException('Playlist not found');
    }

    this.verifyEditAccess(playlist, requesterId);

    // Note: Concurrency and race conditions are handled atomically in the repository.

    const maxIndex = Math.max(0, playlist._count.tracks - 1);
    const normalizedPosition = Math.min(
      Math.max(0, payload.newPosition),
      maxIndex,
    );

    let result;
    try {
      result = await this.playlistsRepository.reorderTrack(
        playlistId,
        playlistTrackId,
        normalizedPosition,
        payload.baseUpdatedAt,
      );
    } catch (error) {
      if (error instanceof OccStaleException) {
        throw new ConflictException(
          'Playlist has been modified by another user. Please refresh to sync.',
        );
      }
      if (error instanceof TrackNotFoundInTransactionException) {
        throw new NotFoundException('Track not found in playlist');
      }
      throw error;
    }

    this.playlistsGateway.server
      .to(`playlist_${playlistId}`)
      .emit('playlist:track:reordered', {
        playlistId,
        newUpdatedAt: result.newUpdatedAt,
        updates: result.updates,
      });

    return { newUpdatedAt: result.newUpdatedAt };
  }
}
