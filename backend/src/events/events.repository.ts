import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  ConflictException,
} from '@nestjs/common';
import { CreateEventDto } from './dto/create-event.dto';
import { UpdateEventDto } from './dto/update-event.dto';
import { PrismaService } from '../prisma/prisma.service';
import { TrackStatus, Prisma, Visibility, Tags } from '@prisma/client';

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
      tracks,
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

      if (tracks && tracks.length > 0) {
        const uniqueProviderTrackIds = Array.from(
          new Set(tracks.map((t) => t.providerTrackId)),
        );

        const uniqueTracksToInsert = uniqueProviderTrackIds.map(
          (provideId) => tracks.find((t) => t.providerTrackId === provideId)!,
        );

        await tx.track.createMany({
          data: uniqueTracksToInsert.map((t) => ({
            providerTrackId: t.providerTrackId,
            title: t.title,
            artist: t.artist || '',
            durationMs: t.durationMs,
            thumbnailUrl: t.thumbnailUrl || '',
          })),
          skipDuplicates: true,
        });

        const createdTracks = await tx.track.findMany({
          where: { providerTrackId: { in: uniqueProviderTrackIds } },
          select: { id: true },
        });

        finalTrackIds.push(...createdTracks.map((t) => t.id));
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

  async explore(
    userId: string,
    options: { page: number; limit: number; search?: string },
  ) {
    const { page, limit, search } = options;
    const skip = (page - 1) * limit;

    const baseCondition: Prisma.EventWhereInput = {
      OR: [
        { visibility: Visibility.PUBLIC },
        { hostId: userId },
        { invites: { some: { userId } } },
      ],
    };

    const searchConditions: Prisma.EventWhereInput[] = [
      { name: { contains: search, mode: 'insensitive' } },
      { description: { contains: search, mode: 'insensitive' } },
    ];

    if (search && Object.values(Tags).includes(search.toUpperCase() as Tags)) {
      searchConditions.push({ tags: { has: search.toUpperCase() as Tags } });
    }

    const where: Prisma.EventWhereInput = search
      ? {
          AND: [
            baseCondition,
            {
              OR: searchConditions,
            },
          ],
        }
      : baseCondition;

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

  async findAll(
    userId: string,
    options: { page: number; limit: number; search?: string },
  ) {
    const { page, limit, search } = options;
    const skip = (page - 1) * limit;

    const baseCondition: Prisma.EventWhereInput = {
      OR: [{ hostId: userId }, { invites: { some: { userId } } }],
    };

    const searchConditions: Prisma.EventWhereInput[] = [
      { name: { contains: search, mode: 'insensitive' } },
      { description: { contains: search, mode: 'insensitive' } },
    ];

    if (search && Object.values(Tags).includes(search.toUpperCase() as Tags)) {
      searchConditions.push({ tags: { has: search.toUpperCase() as Tags } });
    }

    const where: Prisma.EventWhereInput = search
      ? {
          AND: [
            baseCondition,
            {
              OR: searchConditions,
            },
          ],
        }
      : baseCondition;

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
      tracks,
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
      if (playlistIds !== undefined || tracks !== undefined) {
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

        if (tracks && tracks.length > 0) {
          const uniqueProviderTrackIds = Array.from(
            new Set(tracks.map((t) => t.providerTrackId)),
          );

          const uniqueTracksToInsert = uniqueProviderTrackIds.map(
            (provideId) => tracks.find((t) => t.providerTrackId === provideId)!,
          );

          await tx.track.createMany({
            data: uniqueTracksToInsert.map((t) => ({
              providerTrackId: t.providerTrackId,
              title: t.title,
              artist: t.artist || '',
              durationMs: t.durationMs,
              thumbnailUrl: t.thumbnailUrl || '',
            })),
            skipDuplicates: true,
          });

          const createdTracks = await tx.track.findMany({
            where: { providerTrackId: { in: uniqueProviderTrackIds } },
            select: { id: true },
          });

          finalTrackIds.push(...createdTracks.map((t) => t.id));
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

  async appendTracks(
    id: string,
    tracksInput: {
      providerTrackId: string;
      title: string;
      artist?: string;
      durationMs: number;
      thumbnailUrl?: string;
    }[],
  ) {
    return this.prisma.$transaction(async (tx) => {
      // 0. Check event exists
      const existingEvent = await tx.event.findUnique({ where: { id } });
      if (!existingEvent) {
        throw new NotFoundException(`Event with ID ${id} not found`);
      }

      // 1. Process tracks
      if (tracksInput && tracksInput.length > 0) {
        const uniqueProviderTrackIds = Array.from(
          new Set(tracksInput.map((t) => t.providerTrackId)),
        );

        // Deduplicate input tracks based on providerTrackId
        const uniqueTracksToInsert = uniqueProviderTrackIds.map(
          (provideId) =>
            tracksInput.find((t) => t.providerTrackId === provideId)!,
        );

        // Insert new tracks or find existing ones safely via `skipDuplicates`
        await tx.track.createMany({
          data: uniqueTracksToInsert.map((t) => ({
            providerTrackId: t.providerTrackId,
            title: t.title,
            artist: t.artist || '',
            durationMs: t.durationMs,
            thumbnailUrl: t.thumbnailUrl || '',
          })),
          skipDuplicates: true, // Requires Postgres DB connector
        });

        // Fetch inserted / existing Track IDs
        const tracks = await tx.track.findMany({
          where: { providerTrackId: { in: uniqueProviderTrackIds } },
          select: { id: true },
        });

        const uniqueTrackIds = tracks.map((t) => t.id);

        // 2. Create EventTrack records
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

  async inviteUser(eventId: string, hostId: string, invitedUserId: string) {
    const event = await this.prisma.event.findUnique({
      where: { id: eventId },
    });

    if (!event) {
      throw new NotFoundException(`Event with ID ${eventId} not found`);
    }

    if (event.hostId !== hostId) {
      throw new ForbiddenException(
        'Only the host can invite users to this event',
      );
    }

    if (hostId === invitedUserId) {
      throw new ConflictException('You cannot invite yourself to the event');
    }

    const userToInvite = await this.prisma.user.findUnique({
      where: { id: invitedUserId },
    });

    if (!userToInvite) {
      throw new NotFoundException(`User with ID ${invitedUserId} not found`);
    }

    const existingInvite = await this.prisma.eventInvite.findUnique({
      where: {
        eventId_userId: {
          eventId,
          userId: invitedUserId,
        },
      },
    });

    if (existingInvite) {
      throw new ConflictException('User is already invited to this event');
    }

    return this.prisma.eventInvite.create({
      data: {
        eventId,
        userId: invitedUserId,
        status: 'pending',
      },
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
