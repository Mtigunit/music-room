import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import { CreateEventDto } from './dto/create-event.dto';
import { UpdateEventDto } from './dto/update-event.dto';
import { PrismaService } from '../prisma/prisma.service';
import { TrackStatus, Prisma, Visibility, Tags } from '@prisma/client';
import { YoutubeService } from '../tracks/youtube.service';

@Injectable()
export class EventsRepository {
  constructor(
    private readonly prisma: PrismaService,
    private readonly youtubeService: YoutubeService,
  ) {}

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
      startDate,
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
          startDate,
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
        const uniqueProviderTrackIds = Array.from(new Set(tracks));

        const fetchedMetadata = await this.youtubeService.getTrackDetailsBatch(
          uniqueProviderTrackIds,
        );
        await tx.track.createMany({
          data: fetchedMetadata
            .filter((t) => t !== null)
            .map((t) => ({
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
          addedById: hostId,
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
      include: {
        host: {
          select: {
            id: true,
            username: true,
          },
        },
        tracks: {
          include: { track: true },
          take: 10,
          orderBy: [{ voteScore: 'desc' }, { id: 'asc' }],
        },
      },
    });
    if (!event) {
      throw new NotFoundException(`Event with ID ${id} not found`);
    }

    const { tracks, host, ...eventData } = event;
    const formattedTracks = tracks.map((et) => ({
      id: et.id,
      trackId: et.trackId,
      addedById: et.addedById,
      voteScore: et.voteScore,
      status: et.status,
      providerTrackId: et.track.providerTrackId,
      title: et.track.title,
      artist: et.track.artist,
      durationMs: et.track.durationMs,
      thumbnailUrl: et.track.thumbnailUrl,
    }));

    return {
      ...eventData,
      hostname: host.username,
      hostId: host.id,
      tracks: formattedTracks,
    };
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
          const uniqueProviderTrackIds = Array.from(new Set(tracks));

          const fetchedMetadata =
            await this.youtubeService.getTrackDetailsBatch(
              uniqueProviderTrackIds,
            );

          await tx.track.createMany({
            data: fetchedMetadata
              .filter((t) => t !== null)
              .map((t) => ({
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
            addedById: userId,
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

  async getTracks(
    id: string,
    userId: string,
    options: { page: number; limit: number },
  ) {
    const { page, limit } = options;
    const MAX_PAGE_SIZE = 100;
    if (!Number.isInteger(page) || page < 1) {
      throw new BadRequestException(
        '`page` must be an integer greater than or equal to 1',
      );
    }
    if (!Number.isInteger(limit) || limit < 1) {
      throw new BadRequestException(
        '`limit` must be an integer greater than or equal to 1',
      );
    }
    if (limit > MAX_PAGE_SIZE) {
      throw new BadRequestException(
        `\`limit\` must be less than or equal to ${MAX_PAGE_SIZE}`,
      );
    }
    const skip = (page - 1) * limit;

    const existingEvent = await this.prisma.event.findUnique({
      where: { id },
      include: {
        invites: true,
      },
    });

    if (!existingEvent) {
      throw new NotFoundException(`Event with ID ${id} not found`);
    }

    if (
      existingEvent.visibility !== Visibility.PUBLIC &&
      existingEvent.hostId !== userId &&
      !existingEvent.invites.some((i) => i.userId === userId)
    ) {
      throw new ForbiddenException(
        'You do not have permission to view tracks for this event',
      );
    }

    const where: Prisma.EventTrackWhereInput = { eventId: id };

    const [tracks, total] = await Promise.all([
      this.prisma.eventTrack.findMany({
        where,
        include: {
          track: true,
        },
        orderBy: [{ voteScore: 'desc' }, { id: 'asc' }],
        skip,
        take: limit,
      }),
      this.prisma.eventTrack.count({ where }),
    ]);

    const formattedTracks = tracks.map((et) => ({
      id: et.id,
      trackId: et.trackId,
      addedById: et.addedById,
      voteScore: et.voteScore,
      status: et.status,
      providerTrackId: et.track.providerTrackId,
      title: et.track.title,
      artist: et.track.artist,
      durationMs: et.track.durationMs,
      thumbnailUrl: et.track.thumbnailUrl,
    }));

    return {
      data: formattedTracks,
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
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

  async appendTrack(eventId: string, userId: string, providerTrackId: string) {
    const event = await this.prisma.event.findUnique({
      where: { id: eventId },
      include: {
        invites: true,
      },
    });

    if (!event) {
      throw new NotFoundException(`Event with ID ${eventId} not found`);
    }

    if (
      event.visibility !== Visibility.PUBLIC &&
      event.hostId !== userId &&
      !event.invites.some((i) => i.userId === userId)
    ) {
      throw new ForbiddenException(
        'You do not have permission to append tracks to this event',
      );
    }

    if (!providerTrackId || !providerTrackId.trim()) {
      throw new BadRequestException('Provider track ID is required');
    }

    const trackDetails =
      await this.youtubeService.getTrackDetails(providerTrackId);
    if (!trackDetails) {
      throw new NotFoundException('Track metadata not found');
    }

    const track = await this.prisma.track.upsert({
      where: { providerTrackId: trackDetails.providerTrackId },
      create: {
        providerTrackId: trackDetails.providerTrackId,
        title: trackDetails.title,
        artist: trackDetails.artist || '',
        durationMs: trackDetails.durationMs,
        thumbnailUrl: trackDetails.thumbnailUrl || '',
      },
      update: {
        title: trackDetails.title,
        artist: trackDetails.artist || '',
        durationMs: trackDetails.durationMs,
        thumbnailUrl: trackDetails.thumbnailUrl || '',
      },
    });

    const existingEventTrack = await this.prisma.eventTrack.findFirst({
      where: {
        eventId,
        trackId: track.id,
      },
      include: {
        track: {
          select: {
            providerTrackId: true,
          },
        },
      },
    });

    if (existingEventTrack) {
      throw new ConflictException(
        `Track is already attached to this event: ${existingEventTrack.track.providerTrackId}`,
      );
    }

    await this.prisma.eventTrack.create({
      data: {
        eventId,
        trackId: track.id,
        addedById: userId,
        status: TrackStatus.QUEUED,
      },
    });

    const newTrack = await this.prisma.eventTrack.findFirst({
      where: {
        eventId,
        trackId: track.id,
      },
      include: {
        track: true,
      },
    });
    return newTrack;
  }

  async removeTrack(eventId: string, providerTrackId: string, userId: string) {
    const event = await this.prisma.event.findUnique({
      where: { id: eventId },
      select: { hostId: true },
    });

    if (!event) {
      throw new NotFoundException(`Event with ID ${eventId} not found`);
    }

    const eventTrack = await this.prisma.eventTrack.findFirst({
      where: {
        eventId,
        track: {
          providerTrackId,
        },
      },
      select: {
        id: true,
        trackId: true,
        addedById: true,
        track: {
          select: {
            providerTrackId: true,
          },
        },
      },
    });

    if (!eventTrack) {
      throw new NotFoundException(
        `Track with provider ID ${providerTrackId} not found in event`,
      );
    }

    if (event.hostId !== userId && eventTrack.addedById !== userId) {
      throw new ForbiddenException(
        'Only the event host or the user who added this track can remove it',
      );
    }

    await this.prisma.eventTrack.delete({
      where: {
        id: eventTrack.id,
      },
    });

    return {
      trackId: eventTrack.trackId,
      providerTrackId: eventTrack.track.providerTrackId,
    };
  }
}
