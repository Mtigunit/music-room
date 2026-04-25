import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateEventDto } from './dto/create-event.dto';
import { UpdateEventDto } from './dto/update-event.dto';
import {
  TrackStatus,
  Prisma,
  Visibility,
  Tags,
  EventStatus,
} from '@prisma/client';
import { TrackSearchResultDto } from '../tracks/dto/track-search-result.dto';

@Injectable()
export class EventsRepository {
  constructor(private readonly prisma: PrismaService) {}

  async findPlaylistsByIds(playlistIds: string[], userId: string) {
    return this.prisma.playlist.findMany({
      where: {
        id: { in: playlistIds },
        OR: [
          { visibility: Visibility.PUBLIC },
          { ownerId: userId },
          {
            collaborators: {
              some: { userId },
            },
          },
        ],
      },
      select: { id: true },
    });
  }

  async findUserById(id: string) {
    return this.prisma.user.findUnique({
      where: { id },
    });
  }

  async findById(id: string) {
    return this.prisma.event.findUnique({
      where: { id },
    });
  }

  async findByIdWithDetails(id: string) {
    const event = await this.prisma.event.findUnique({
      where: { id },
      include: {
        host: {
          select: { id: true, username: true },
        },
        invites: true,
        tracks: {
          include: { track: true },
          take: 10,
          orderBy: [{ voteScore: 'desc' }, { id: 'asc' }],
        },
      },
    });

    if (!event) return null;

    const formattedTracks = event.tracks.map((et) => ({
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

    return { ...event, tracks: formattedTracks };
  }

  async findByIdWithInvites(id: string) {
    return this.prisma.event.findUnique({
      where: { id },
      include: { invites: true },
    });
  }

  async createEvent(
    hostId: string,
    createEventDto: CreateEventDto,
    fetchedTracks: TrackSearchResultDto[],
  ) {
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
      startDate,
    } = createEventDto;

    return this.prisma.$transaction(async (tx) => {
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

      let finalTrackIds: string[] = [];

      if (playlistIds && playlistIds.length > 0) {
        const playlistTracks = await tx.playlistTrack.findMany({
          where: { playlistId: { in: playlistIds } },
          orderBy: [{ playlistId: 'asc' }, { position: 'asc' }],
          select: { trackId: true },
        });
        finalTrackIds.push(...playlistTracks.map((pt) => pt.trackId));
      }

      if (fetchedTracks && fetchedTracks.length > 0) {
        await tx.track.createMany({
          data: fetchedTracks.map((t) => ({
            providerTrackId: t.providerTrackId,
            title: t.title,
            artist: t.artist || '',
            durationMs: t.durationMs,
            thumbnailUrl: t.thumbnailUrl || '',
          })),
          skipDuplicates: true,
        });

        const providerIds = fetchedTracks.map((t) => t.providerTrackId);
        const createdTracks = await tx.track.findMany({
          where: { providerTrackId: { in: providerIds } },
          select: { id: true },
        });

        finalTrackIds.push(...createdTracks.map((t) => t.id));
      }

      finalTrackIds = Array.from(new Set(finalTrackIds));

      if (finalTrackIds.length > 0) {
        const eventTracksData = finalTrackIds.map((trackId) => ({
          eventId: event.id,
          trackId,
          addedById: hostId,
          status: TrackStatus.QUEUED,
        }));
        await tx.eventTrack.createMany({ data: eventTracksData });
      }

      return event;
    });
  }

  async updateEvent(
    id: string,
    userId: string,
    updateEventDto: UpdateEventDto,
    fetchedTracks: TrackSearchResultDto[],
  ) {
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
      const updatedEvent = await tx.event.update({
        where: { id },
        data: {
          name,
          ...(description !== undefined && { description }),
          ...(coverImage !== undefined && { coverImage }),
          visibility,
          invitingOnly,
          tags,
          locationLat,
          locationLng,
          ...(policies && {
            policies: {
              deleteMany: {},
              create: policies.map((p) => ({
                policyType: p.policyType,
                config: p.config as Prisma.InputJsonValue,
              })),
            },
          }),
        },
      });

      if (playlistIds !== undefined || tracks !== undefined) {
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

        if (fetchedTracks && fetchedTracks.length > 0) {
          await tx.track.createMany({
            data: fetchedTracks.map((t) => ({
              providerTrackId: t.providerTrackId,
              title: t.title,
              artist: t.artist || '',
              durationMs: t.durationMs,
              thumbnailUrl: t.thumbnailUrl || '',
            })),
            skipDuplicates: true,
          });

          const providerIds = fetchedTracks.map((t) => t.providerTrackId);
          const createdTracks = await tx.track.findMany({
            where: { providerTrackId: { in: providerIds } },
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
          await tx.eventTrack.createMany({ data: eventTracksData });
        }
      }

      return updatedEvent;
    });
  }

  async findAll(
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
      ? { AND: [baseCondition, { OR: searchConditions }] }
      : baseCondition;

    const [data, total] = await Promise.all([
      this.prisma.event.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: { host: { select: { id: true, username: true } } },
      }),
      this.prisma.event.count({ where }),
    ]);

    const formattedData = data.map((event) => {
      const { host, ...rest } = event;
      return {
        ...rest,
        host: host ? { id: host.id, name: host.username } : null,
      };
    });

    return {
      data: formattedData,
      meta: { total, page, limit, totalPages: Math.ceil(total / limit) },
    };
  }

  async findHosting(
    userId: string,
    options: { page: number; limit: number; search?: string },
  ) {
    const { page, limit, search } = options;
    const skip = (page - 1) * limit;

    const baseCondition: Prisma.EventWhereInput = { hostId: userId };

    const searchConditions: Prisma.EventWhereInput[] = [
      { name: { contains: search, mode: 'insensitive' } },
      { description: { contains: search, mode: 'insensitive' } },
    ];

    if (search && Object.values(Tags).includes(search.toUpperCase() as Tags)) {
      searchConditions.push({ tags: { has: search.toUpperCase() as Tags } });
    }

    const where: Prisma.EventWhereInput = search
      ? { AND: [baseCondition, { OR: searchConditions }] }
      : baseCondition;

    const [data, total] = await Promise.all([
      this.prisma.event.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: { host: { select: { id: true, username: true } } },
      }),
      this.prisma.event.count({ where }),
    ]);

    const formattedData = data.map((event) => {
      const { host, ...rest } = event;
      return {
        ...rest,
        host: host ? { id: host.id, name: host.username } : null,
      };
    });

    return {
      data: formattedData,
      meta: { total, page, limit, totalPages: Math.ceil(total / limit) },
    };
  }

  async findInvited(
    userId: string,
    options: { page: number; limit: number; search?: string },
  ) {
    const { page, limit, search } = options;
    const skip = (page - 1) * limit;

    const baseCondition: Prisma.EventWhereInput = {
      invites: { some: { userId } },
    };

    const searchConditions: Prisma.EventWhereInput[] = [
      { name: { contains: search, mode: 'insensitive' } },
      { description: { contains: search, mode: 'insensitive' } },
    ];

    if (search && Object.values(Tags).includes(search.toUpperCase() as Tags)) {
      searchConditions.push({ tags: { has: search.toUpperCase() as Tags } });
    }

    const where: Prisma.EventWhereInput = search
      ? { AND: [baseCondition, { OR: searchConditions }] }
      : baseCondition;

    const [data, total] = await Promise.all([
      this.prisma.event.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: { host: { select: { id: true, username: true } } },
      }),
      this.prisma.event.count({ where }),
    ]);

    const formattedData = data.map((event) => {
      const { host, ...rest } = event;
      return {
        ...rest,
        host: host ? { id: host.id, name: host.username } : null,
      };
    });

    return {
      data: formattedData,
      meta: { total, page, limit, totalPages: Math.ceil(total / limit) },
    };
  }

  async findInvite(eventId: string, userId: string) {
    return this.prisma.eventInvite.findUnique({
      where: { eventId_userId: { eventId, userId } },
    });
  }

  async createInvite(eventId: string, userId: string) {
    return this.prisma.eventInvite.create({
      data: { eventId, userId, status: 'pending' },
    });
  }

  async updateStatus(id: string, status: EventStatus, startDate?: Date) {
    return this.prisma.event.update({
      where: { id },
      data: { status, ...(startDate && { startDate }) },
    });
  }

  async deleteEvent(id: string) {
    return this.prisma.event.delete({
      where: { id },
    });
  }

  async getTracks(eventId: string, skip: number, take: number) {
    const where: Prisma.EventTrackWhereInput = { eventId };

    const [tracks, total] = await Promise.all([
      this.prisma.eventTrack.findMany({
        where,
        include: { track: true },
        orderBy: [{ voteScore: 'desc' }, { id: 'asc' }],
        skip,
        take,
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

    return { tracks: formattedTracks, total };
  }

  async upsertTrackAndGet(trackDetails: TrackSearchResultDto) {
    return this.prisma.track.upsert({
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
  }

  async findEventTrack(eventId: string, trackId: string) {
    return this.prisma.eventTrack.findFirst({
      where: { eventId, trackId },
      include: { track: { select: { providerTrackId: true } } },
    });
  }

  async findEventTrackByProviderId(eventId: string, providerTrackId: string) {
    return this.prisma.eventTrack.findFirst({
      where: { eventId, track: { providerTrackId } },
      select: {
        id: true,
        trackId: true,
        addedById: true,
        track: { select: { providerTrackId: true } },
      },
    });
  }

  async createEventTrack(eventId: string, trackId: string, addedById: string) {
    await this.prisma.eventTrack.create({
      data: {
        eventId,
        trackId,
        addedById,
        status: TrackStatus.QUEUED,
      },
    });

    return this.prisma.eventTrack.findFirst({
      where: { eventId, trackId },
      include: { track: true },
    });
  }

  async deleteEventTrack(id: string) {
    return this.prisma.eventTrack.delete({
      where: { id },
    });
  }
}
