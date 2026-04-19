import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { CreateEventDto } from './dto/create-event.dto';
import { UpdateEventDto } from './dto/update-event.dto';
import { PrismaService } from '../prisma/prisma.service';
import { TrackStatus, Prisma } from '@prisma/client';

@Injectable()
export class EventsRepository {
  constructor(private readonly prisma: PrismaService) {}

  async create(hostId: string, createEventDto: CreateEventDto) {
    const {
      name,
      description,
      coverImage,
      visibility,
      invitingOnly,
      tags,
      locationLat,
      locationLng,
      policies,
      playlistIds,
      trackIds,
    } = createEventDto;

    return this.prisma.$transaction(async (tx) => {
      // 0. Validate playlistIds and trackIds before creating anything
      if (playlistIds && playlistIds.length > 0) {
        const uniquePlaylistIds = Array.from(new Set(playlistIds));
        const playlists = await tx.playlist.findMany({
          where: { id: { in: uniquePlaylistIds } },
          select: { id: true },
        });
        if (playlists.length !== uniquePlaylistIds.length) {
          const foundIds = playlists.map((p) => p.id);
          const missingIds = uniquePlaylistIds.filter(
            (id) => !foundIds.includes(id),
          );
          throw new NotFoundException(
            `Playlists not found: ${missingIds.join(', ')}`,
          );
        }
      }

      if (trackIds && trackIds.length > 0) {
        const uniqueTrackIds = Array.from(new Set(trackIds));
        const tracks = await tx.track.findMany({
          where: { id: { in: uniqueTrackIds } },
          select: { id: true },
        });
        if (tracks.length !== uniqueTrackIds.length) {
          const foundIds = tracks.map((t) => t.id);
          const missingIds = uniqueTrackIds.filter(
            (id) => !foundIds.includes(id),
          );
          throw new NotFoundException(
            `Tracks not found: ${missingIds.join(', ')}`,
          );
        }
      }

      // 1. Create the Event
      const event = await tx.event.create({
        data: {
          name,
          description,
          coverImage: coverImage || '',
          visibility,
          invitingOnly,
          tags,
          hostId,
          locationLat,
          locationLng,
          // Handle policies
          policies: policies?.length
            ? {
                create: policies.map((p) => ({
                  policyType: p.policyType,
                  config: p.config as Prisma.InputJsonValue,
                })),
              }
            : undefined,
        },
      });

      // 2. Track resolution logic
      let finalTrackIds: string[] = [];

      if (playlistIds && playlistIds.length > 0) {
        const playlistTracks = await tx.playlistTrack.findMany({
          where: {
            playlistId: { in: playlistIds },
          },
          orderBy: [{ playlistId: 'asc' }, { position: 'asc' }],
          select: { trackId: true },
        });

        finalTrackIds.push(...playlistTracks.map((pt) => pt.trackId));
      }

      if (trackIds && trackIds.length > 0) {
        finalTrackIds.push(...trackIds);
      }

      // Deduplicate using a Set
      finalTrackIds = Array.from(new Set(finalTrackIds));

      // 3. Insert as EventTrack records
      if (finalTrackIds.length > 0) {
        const eventTracksData = finalTrackIds.map((trackId) => ({
          eventId: event.id,
          trackId,
          status: TrackStatus.QUEUED,
        }));

        await tx.eventTrack.createMany({
          data: eventTracksData,
        });
      }

      return event;
    });
  }

  async findAll(options: { page: number; limit: number; name?: string }) {
    const { page, limit, name } = options;
    const skip = (page - 1) * limit;

    const where: Prisma.EventWhereInput = {};
    if (name) {
      where.name = {
        contains: name,
        mode: 'insensitive',
      };
    }

    const [data, total] = await Promise.all([
      this.prisma.event.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.event.count({ where }),
    ]);

    return {
      data,
      meta: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async findOne(id: string) {
    const event = await this.prisma.event.findUnique({
      where: { id },
    });

    if (!event) {
      throw new NotFoundException(`Event with ID ${id} not found`);
    }

    return event;
  }

  async update(id: string, userId: string, updateEventDto: UpdateEventDto) {
    const {
      name,
      description,
      coverImage,
      visibility,
      invitingOnly,
      tags,
      locationLat,
      locationLng,
      policies,
      playlistIds,
      trackIds,
    } = updateEventDto;

    return this.prisma.$transaction(async (tx) => {
      // 0. Check event exists
      const existingEvent = await tx.event.findUnique({ where: { id } });
      if (!existingEvent) {
        throw new NotFoundException(`Event with ID ${id} not found`);
      }
      if (existingEvent.hostId !== userId) {
        throw new ForbiddenException(
          `You are not authorized to update this event`,
        );
      }

      // 1. Validate playlistIds and trackIds before creating anything
      if (playlistIds && playlistIds.length > 0) {
        const uniquePlaylistIds = Array.from(new Set(playlistIds));
        const playlists = await tx.playlist.findMany({
          where: { id: { in: uniquePlaylistIds } },
          select: { id: true },
        });
        if (playlists.length !== uniquePlaylistIds.length) {
          const foundIds = playlists.map((p) => p.id);
          const missingIds = uniquePlaylistIds.filter(
            (id) => !foundIds.includes(id),
          );
          throw new NotFoundException(
            `Playlists not found: ${missingIds.join(', ')}`,
          );
        }
      }

      if (trackIds && trackIds.length > 0) {
        const uniqueTrackIds = Array.from(new Set(trackIds));
        const tracks = await tx.track.findMany({
          where: { id: { in: uniqueTrackIds } },
          select: { id: true },
        });
        if (tracks.length !== uniqueTrackIds.length) {
          const foundIds = tracks.map((t) => t.id);
          const missingIds = uniqueTrackIds.filter(
            (id) => !foundIds.includes(id),
          );
          throw new NotFoundException(
            `Tracks not found: ${missingIds.join(', ')}`,
          );
        }
      }

      // 2. Update the Event
      const updatedEvent = await tx.event.update({
        where: { id },
        data: {
          name,
          ...(description !== undefined && { description }), // Mapping typo
          ...(coverImage !== undefined && { coverImage }),
          visibility,
          invitingOnly,
          tags,
          locationLat,
          locationLng,
          ...(policies && {
            policies: {
              deleteMany: {}, // replace all existing policies
              create: policies.map((p) => ({
                policyType: p.policyType,
                config: p.config as Prisma.InputJsonValue,
              })),
            },
          }),
        },
      });

      // 3. Track resolution logic
      if (playlistIds !== undefined || trackIds !== undefined) {
        // clear existing tracks and re-insert
        await tx.eventTrack.deleteMany({ where: { eventId: id } });

        let finalTrackIds: string[] = [];

        if (playlistIds && playlistIds.length > 0) {
          const playlistTracks = await tx.playlistTrack.findMany({
            where: { playlistId: { in: playlistIds } },
            orderBy: [{ playlistId: 'asc' }, { position: 'asc' }],
            select: { trackId: true },
          });

          finalTrackIds.push(...playlistTracks.map((pt) => pt.trackId));
        }

        if (trackIds && trackIds.length > 0) {
          finalTrackIds.push(...trackIds);
        }

        finalTrackIds = Array.from(new Set(finalTrackIds));

        if (finalTrackIds.length > 0) {
          const eventTracksData = finalTrackIds.map((trackId) => ({
            eventId: id,
            trackId,
            status: TrackStatus.QUEUED,
          }));

          await tx.eventTrack.createMany({
            data: eventTracksData,
          });
        }
      }

      return updatedEvent;
    });
  }

  async appendTracks(id: string, trackIds: string[]) {
    return this.prisma.$transaction(async (tx) => {
      // 0. Check event exists
      const existingEvent = await tx.event.findUnique({ where: { id } });
      if (!existingEvent) {
        throw new NotFoundException(`Event with ID ${id} not found`);
      }

      // 1. Verify tracks exist
      if (trackIds && trackIds.length > 0) {
        const uniqueTrackIds = Array.from(new Set(trackIds));
        const tracks = await tx.track.findMany({
          where: { id: { in: uniqueTrackIds } },
          select: { id: true },
        });
        if (tracks.length !== uniqueTrackIds.length) {
          const foundIds = tracks.map((t) => t.id);
          const missingIds = uniqueTrackIds.filter(
            (tId) => !foundIds.includes(tId),
          );
          throw new NotFoundException(
            `Tracks not found: ${missingIds.join(', ')}`,
          );
        }

        // 2. Create EventTrack records, bypassing existing ones safely via `skipDuplicates`
        const eventTracksData = uniqueTrackIds.map((trackId) => ({
          eventId: id,
          trackId,
          status: TrackStatus.QUEUED,
        }));

        await tx.eventTrack.createMany({
          data: eventTracksData,
          skipDuplicates: true, // Requires Postgres DB connector
        });
      }

      return tx.event.findUnique({
        where: { id },
        include: { tracks: true },
      });
    });
  }

  async remove(id: string, userId: string) {
    const event = await this.prisma.event.findUnique({
      where: { id },
      select: { hostId: true },
    });

    if (!event) {
      throw new NotFoundException(`Event with ID ${id} not found`);
    }

    if (event.hostId !== userId) {
      throw new ForbiddenException('Only the host can delete this event');
    }

    try {
      await this.prisma.event.delete({
        where: { id },
      });
      return { message: 'Event successfully deleted' };
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2025'
      ) {
        throw new NotFoundException(`Event with ID ${id} not found`);
      }
      throw error;
    }
  }
}
