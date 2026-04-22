import { Injectable } from '@nestjs/common';
import { Tags, Visibility, type PlaylistTrack, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { TrackSearchResultDto } from '../tracks/dto/track-search-result.dto';
import { CreatePlaylistDto } from './dto/create-playlist.dto';
import { UpdatePlaylistDto } from './dto/update-playlist.dto';
import { PaginationDto } from '../common/dto/pagination.dto';
import { PlaylistAuthData } from './interfaces/playlist-auth-data.interface';

@Injectable()
export class PlaylistsRepository {
  constructor(private readonly prisma: PrismaService) {}

  async createPlaylist(userId: string, dto: CreatePlaylistDto) {
    return this.prisma.$transaction(async (tx) => {
      const playlist = await tx.playlist.create({
        data: {
          name: dto.name,
          visibility: dto.visibility,
          editLicense: dto.editLicense,
          description: dto.description,
          tags: dto.tags || [],
          owner: {
            connect: { id: userId },
          },
          counter: {
            create: {
              nextPosition: -1,
            },
          },
        },
      });
      return playlist;
    });
  }

  async getUserPlaylists(userId: string, paginationDto: PaginationDto) {
    const { page = 1, limit = 20 } = paginationDto;
    const skip = (page - 1) * limit;

    const where: Prisma.PlaylistWhereInput = {
      OR: [{ ownerId: userId }, { collaborators: { some: { userId } } }],
    };

    const [data, total] = await Promise.all([
      this.prisma.playlist.findMany({
        where,
        include: {
          _count: {
            select: { tracks: true },
          },
        },
        orderBy: { updatedAt: 'desc' },
        skip,
        take: limit,
      }),
      this.prisma.playlist.count({ where }),
    ]);

    return { data, meta: { total, page, limit } };
  }

  async explorePublicPlaylists(
    searchQuery: string | undefined,
    tag: Tags | undefined,
    paginationDto: PaginationDto,
  ) {
    const { page = 1, limit = 20 } = paginationDto;
    const skip = (page - 1) * limit;

    const where: Prisma.PlaylistWhereInput = {
      visibility: Visibility.PUBLIC,
    };

    if (searchQuery) {
      const normalized = searchQuery.trim().toUpperCase();
      const searchTag = (Object.values(Tags) as string[]).includes(normalized)
        ? (normalized as Tags)
        : undefined;

      where.OR = [
        { name: { contains: searchQuery, mode: 'insensitive' } },
        { description: { contains: searchQuery, mode: 'insensitive' } },
        ...(searchTag ? [{ tags: { has: searchTag } }] : []),
      ];
    }

    if (tag) {
      where.tags = { has: tag };
    }

    const [data, total] = await Promise.all([
      this.prisma.playlist.findMany({
        where,
        include: {
          owner: {
            select: { id: true, username: true },
          },
          _count: {
            select: { tracks: true },
          },
        },
        orderBy: { updatedAt: 'desc' },
        skip,
        take: limit,
      }),
      this.prisma.playlist.count({ where }),
    ]);

    return { data, meta: { total, page, limit } };
  }

  async findPlaylistForAuth(
    playlistId: string,
  ): Promise<PlaylistAuthData | null> {
    return this.prisma.playlist.findUnique({
      where: { id: playlistId },
      select: {
        id: true,
        ownerId: true,
        visibility: true,
        editLicense: true,
        collaborators: {
          select: { userId: true },
        },
        _count: {
          select: { tracks: true },
        },
      },
    });
  }

  async getPlaylistDetails(playlistId: string) {
    return this.prisma.playlist.findUnique({
      where: { id: playlistId },
      include: {
        collaborators: {
          include: {
            user: { select: { id: true, username: true } },
          },
        },
        tracks: {
          orderBy: { position: 'asc' },
          include: {
            track: true,
            addedBy: { select: { id: true, username: true } },
          },
        },
        owner: { select: { id: true, username: true } },
      },
    });
  }

  async updatePlaylist(playlistId: string, dto: UpdatePlaylistDto) {
    return this.prisma.playlist.update({
      where: { id: playlistId },
      data: dto,
    });
  }

  async deletePlaylist(playlistId: string) {
    return this.prisma.playlist.delete({
      where: { id: playlistId },
    });
  }

  async addCollaborator(playlistId: string, targetUserId: string) {
    return this.prisma.playlistCollaborator.upsert({
      where: {
        playlistId_userId: {
          playlistId,
          userId: targetUserId,
        },
      },
      create: {
        playlistId,
        userId: targetUserId,
      },
      update: {}, // Already exists, do nothing
      include: {
        user: { select: { id: true, username: true } },
      },
    });
  }

  async addTrackToPlaylist(
    playlistId: string,
    addedById: string,
    track: TrackSearchResultDto,
  ): Promise<PlaylistTrack> {
    return this.prisma.$transaction(async (tx) => {
      const counter = await tx.playlistCounter.update({
        where: { playlistId },
        data: { nextPosition: { increment: 1 } },
        select: { nextPosition: true },
      });

      await tx.playlist.update({
        where: { id: playlistId },
        data: { updatedAt: new Date() },
      });

      return tx.playlistTrack.create({
        data: {
          playlist: { connect: { id: playlistId } },
          position: counter.nextPosition, // Atomic increment returns the post-increment value; counter starts at -1 so this is exactly the 0-based position
          addedBy: { connect: { id: addedById } },
          track: {
            connectOrCreate: {
              where: { providerTrackId: track.providerTrackId },
              create: {
                providerTrackId: track.providerTrackId,
                title: track.title,
                artist: track.artist,
                durationMs: track.durationMs,
                thumbnailUrl: track.thumbnailUrl,
              },
            },
          },
        },
        include: { track: true },
      });
    });
  }

  async isTrackInPlaylist(playlistId: string, providerTrackId: string) {
    // 1. Find the track ID first using the unique providerTrackId index
    const track = await this.prisma.track.findUnique({
      where: { providerTrackId },
      select: { id: true },
    });

    if (!track) {
      return false;
    }

    // 2. Check if this specific track is in the specific playlist using the compound unique index
    const playlistTrack = await this.prisma.playlistTrack.findUnique({
      where: {
        playlistId_trackId: {
          playlistId,
          trackId: track.id,
        },
      },
      select: { id: true },
    });

    return !!playlistTrack;
  }

  async findPlaylistTrack(playlistId: string, playlistTrackId: string) {
    return this.prisma.playlistTrack.findFirst({
      where: { id: playlistTrackId, playlistId },
      include: { track: true },
    });
  }

  async removeTrackFromPlaylist(playlistId: string, playlistTrackId: string) {
    return this.prisma.$transaction(async (tx) => {
      // 1. Find the track to know its position, scoped to the playlist
      const track = await tx.playlistTrack.findFirst({
        where: { id: playlistTrackId, playlistId },
        select: { position: true },
      });

      if (!track) {
        return null;
      }

      // 2. Delete the track, scoped to context
      const deletedTrack = await tx.playlistTrack.delete({
        where: { id: playlistTrackId, playlistId },
        include: { track: true },
      });

      // 3. Shift subsequent tracks down to fill the integer gap
      await tx.playlistTrack.updateMany({
        where: {
          playlistId,
          position: { gt: track.position },
        },
        data: {
          position: { decrement: 1 },
        },
      });

      // 4. Decrement the counter
      await tx.playlistCounter.update({
        where: { playlistId },
        data: { nextPosition: { decrement: 1 } },
      });

      // 5. Bump the Playlist updatedAt timestamp for Optimistic Concurrency Control
      await tx.playlist.update({
        where: { id: playlistId },
        data: { updatedAt: new Date() },
      });

      // 6. Fetch the updated tracks that were shifted to broadcast their new absolute positions
      const updates = await tx.playlistTrack.findMany({
        where: {
          playlistId,
          position: { gte: track.position }, // `track.position` is the deleted track's original position; after decrementing subsequent tracks, shifted tracks now occupy positions starting from this value
        },
        select: {
          id: true,
          position: true,
        },
      });

      return {
        deletedTrack,
        updates: updates.map((u) => ({ trackId: u.id, position: u.position })),
      };
    });
  }

  async checkUserExists(userId: string): Promise<boolean> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    return !!user;
  }
}
