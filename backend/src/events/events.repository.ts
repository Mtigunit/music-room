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
  PlaybackStatus,
} from '@prisma/client';
import { TrackSearchResultDto } from '../tracks/dto/track-search-result.dto';
import { EventQueryDto } from './dto/event-query.dto';
import { PaginationDto } from '../common/dto/pagination.dto';

const firstTrackSelect = {
  select: { track: { select: { thumbnailUrl: true } } },
  take: 1,
  orderBy: [{ voteScore: 'desc' as const }, { id: 'asc' as const }],
};

type EventListItem = Prisma.EventGetPayload<{
  include: {
    host: { select: { id: true; username: true } };
    tracks: {
      select: { track: { select: { thumbnailUrl: true } } };
    };
    _count: { select: { invites: true } };
  };
}>;

@Injectable()
export class EventsRepository {
  constructor(private readonly prisma: PrismaService) {}

  private formatEventList(data: EventListItem[]) {
    return data.map((event) => {
      const { host, tracks, _count, ...rest } = event;
      const firstTrack = tracks[0];
      return {
        ...rest,
        host: host ? { id: host.id, name: host.username } : null,
        firstTrack: firstTrack ? firstTrack.track.thumbnailUrl : null,
        membersCount: (_count?.invites ?? 0) + 1,
      };
    });
  }

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

  async findByIdWithDetails(id: string, userId: string) {
    const event = await this.prisma.event.findUnique({
      where: { id },
      include: {
        host: {
          select: { id: true, username: true },
        },
        invites: {
          where: { userId },
          select: { id: true },
        },
        tracks: {
          include: { track: true },
          take: 10,
          orderBy: [{ voteScore: 'desc' }, { id: 'asc' }],
        },
        policies: { select: { config: true, policyType: true } },
        delegations: {
          where: { isActive: true, delegateeId: userId },
          select: { delegateeId: true },
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
        include: {
          host: { select: { id: true, username: true } },
          tracks: firstTrackSelect,
          _count: { select: { invites: true } },
        },
      }),
      this.prisma.event.count({ where }),
    ]);

    return {
      data: this.formatEventList(data),
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
        include: {
          host: { select: { id: true, username: true } },
          tracks: firstTrackSelect,
          _count: { select: { invites: true } },
        },
      }),
      this.prisma.event.count({ where }),
    ]);

    return {
      data: this.formatEventList(data),
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
        include: {
          host: { select: { id: true, username: true } },
          tracks: firstTrackSelect,
          _count: { select: { invites: true } },
        },
      }),
      this.prisma.event.count({ where }),
    ]);

    return {
      data: this.formatEventList(data),
      meta: { total, page, limit, totalPages: Math.ceil(total / limit) },
    };
  }

  async findExplore(userId: string, query: EventQueryDto) {
    const { page = 1, limit = 10, search, status, tags } = query;
    const skip = (page - 1) * limit;

    const baseCondition: Prisma.EventWhereInput = {
      OR: [
        { visibility: Visibility.PUBLIC },
        { hostId: userId },
        { invites: { some: { userId } } },
      ],
    };

    const filters: Prisma.EventWhereInput[] = [];
    if (status) filters.push({ status });
    if (tags && tags.length > 0) filters.push({ tags: { hasSome: tags } });
    if (search) {
      filters.push({
        OR: [
          { name: { contains: search, mode: 'insensitive' } },
          { description: { contains: search, mode: 'insensitive' } },
        ],
      });
    }

    const where: Prisma.EventWhereInput = {
      AND: [baseCondition, ...filters],
    };

    const [data, total] = await Promise.all([
      this.prisma.event.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          host: { select: { id: true, username: true } },
          tracks: firstTrackSelect,
          _count: { select: { invites: true } },
        },
      }),
      this.prisma.event.count({ where }),
    ]);

    return {
      data: this.formatEventList(data),
      meta: { total, page, limit, totalPages: Math.ceil(total / limit) },
    };
  }

  async findFriendsEvents(userId: string, query: EventQueryDto) {
    const { page = 1, limit = 10, search, status, tags } = query;
    const skip = (page - 1) * limit;

    const friendsCondition: Prisma.EventWhereInput = {
      OR: [
        // Public events from mutual friends
        {
          AND: [
            {
              host: {
                followers: { some: { followerId: userId } },
                following: { some: { followingId: userId } },
              },
            },
            { visibility: Visibility.PUBLIC },
          ],
        },
        // Private events from mutual friends where I'm invited
        {
          AND: [
            { invites: { some: { userId } } },
            {
              host: {
                followers: { some: { followerId: userId } },
                following: { some: { followingId: userId } },
              },
            },
          ],
        },
      ],
    };

    const filters: Prisma.EventWhereInput[] = [];
    if (status) filters.push({ status });
    if (tags && tags.length > 0) filters.push({ tags: { hasSome: tags } });
    if (search) {
      filters.push({
        OR: [
          { name: { contains: search, mode: 'insensitive' } },
          { description: { contains: search, mode: 'insensitive' } },
        ],
      });
    }

    const where: Prisma.EventWhereInput = {
      AND: [friendsCondition, ...filters],
    };

    const [data, total] = await Promise.all([
      this.prisma.event.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          host: { select: { id: true, username: true } },
          tracks: firstTrackSelect,
          _count: { select: { invites: true } },
        },
      }),
      this.prisma.event.count({ where }),
    ]);

    return {
      data: this.formatEventList(data),
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
      data: { eventId, userId },
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

  async getTracks(
    eventId: string,
    skip: number,
    take: number,
    userId: string,
    status: EventStatus,
  ) {
    const where: Prisma.EventTrackWhereInput = {
      eventId,
      ...(status === EventStatus.LIVE && {
        status: { not: TrackStatus.ENDED },
      }),
    };

    const [tracks, total] = await Promise.all([
      this.prisma.eventTrack.findMany({
        where,
        include: {
          track: true,
          votes: { where: { userId }, select: { voteValue: true } },
        },
        orderBy: [{ voteScore: 'desc' }, { id: 'asc' }],
        skip,
        take,
      }),
      this.prisma.eventTrack.count({ where }),
    ]);

    const formattedTracks = tracks.map((et) => {
      const userVote = et.votes[0] ?? null;
      return {
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
        isVoted: userVote !== null,
        voteValue: userVote?.voteValue ?? null,
      };
    });

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
      where: { eventId, trackId, status: { not: TrackStatus.ENDED } },
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

  async getCurrentTrackPayload(eventTrackId: string | null) {
    if (!eventTrackId) return null;
    const eventTrack = await this.prisma.eventTrack.findUnique({
      where: { id: eventTrackId },
      include: { track: true },
    });
    if (!eventTrack) return null;
    return {
      id: eventTrack.id,
      providerTrackId: eventTrack.track.providerTrackId,
      title: eventTrack.track.title,
      artist: eventTrack.track.artist,
      durationMs: eventTrack.track.durationMs,
      thumbnailUrl: eventTrack.track.thumbnailUrl,
    };
  }

  async createEventTrack(eventId: string, trackId: string, addedById: string) {
    return await this.prisma.eventTrack.upsert({
      where: { eventId_trackId: { eventId, trackId } },
      create: {
        eventId,
        trackId,
        addedById,
        status: TrackStatus.QUEUED,
      },
      update: {
        addedById,
        status: TrackStatus.QUEUED,
        voteScore: 0,
      },
      include: { track: true },
    });
  }

  async deleteEventTrack(id: string) {
    return this.prisma.eventTrack.delete({
      where: { id },
    });
  }

  async updatePlaybackPlay(eventId: string) {
    return this.prisma.event.update({
      where: { id: eventId },
      data: {
        playbackStatus: PlaybackStatus.PLAYING,
        currentTrackStartedAt: new Date(),
      },
    });
  }

  async updatePlaybackPause(eventId: string, positionMs: number) {
    return this.prisma.event.update({
      where: { id: eventId },
      data: {
        playbackStatus: PlaybackStatus.PAUSED,
        currentTrackStartedAt: null,
        pausedPlaybackPositionMs: positionMs,
      },
    });
  }

  async advanceQueue(eventId: string) {
    return this.prisma.$transaction(async (tx) => {
      const event = await tx.event.findUnique({ where: { id: eventId } });
      if (!event) return null;

      if (event.currentTrackId) {
        await tx.eventTrack.update({
          where: { id: event.currentTrackId },
          data: { status: TrackStatus.ENDED },
        });
      }

      const nextTrack = await tx.eventTrack.findFirst({
        where: { eventId, status: TrackStatus.QUEUED },
        orderBy: [{ voteScore: 'desc' }, { id: 'asc' }],
      });

      if (nextTrack) {
        await tx.eventTrack.update({
          where: { id: nextTrack.id },
          data: { status: TrackStatus.PLAYING },
        });
        const updatedEvent = await tx.event.update({
          where: { id: eventId },
          data: {
            currentTrackId: nextTrack.id,
            currentTrackStartedAt: new Date(),
            pausedPlaybackPositionMs: 0,
            playbackStatus: PlaybackStatus.PLAYING,
          },
        });
        return { event: updatedEvent, nextTrackId: nextTrack.id };
      } else {
        const updatedEvent = await tx.event.update({
          where: { id: eventId },
          data: {
            currentTrackId: null,
            currentTrackStartedAt: null,
            pausedPlaybackPositionMs: 0,
            playbackStatus: PlaybackStatus.PAUSED,
          },
        });
        return { event: updatedEvent, nextTrackId: null };
      }
    });
  }

  async setInitialTrack(eventId: string, trackId: string) {
    return this.prisma.event.update({
      where: { id: eventId },
      data: {
        currentTrackId: trackId,
        playbackStatus: PlaybackStatus.PAUSED,
        currentTrackStartedAt: null,
        pausedPlaybackPositionMs: 0,
      },
    });
  }

  async findActiveDelegation(eventId: string, delegateeId: string) {
    return this.prisma.controlDelegation.findFirst({
      where: {
        eventId,
        delegateeId,
        isActive: true,
      },
      select: {
        deviceId: true,
      },
    });
  }

  async findHostLiveEvent(userId: string, excludeEventId?: string) {
    return this.prisma.event.findFirst({
      where: {
        hostId: userId,
        status: EventStatus.LIVE,
        ...(excludeEventId && { id: { not: excludeEventId } }),
      },
      select: {
        id: true,
        currentTrackId: true,
        playbackStatus: true,
        currentTrackStartedAt: true,
        pausedPlaybackPositionMs: true,
      },
    });
  }

  async startEvent(eventId: string) {
    return this.prisma.$transaction(async (tx) => {
      const firstTrack = await tx.eventTrack.findFirst({
        where: { eventId, status: TrackStatus.QUEUED },
        orderBy: [{ voteScore: 'desc' }, { id: 'asc' }],
      });

      return tx.event.update({
        where: { id: eventId },
        data: {
          status: EventStatus.LIVE,
          startDate: new Date(),
          currentTrackId: firstTrack ? firstTrack.id : null,
          playbackStatus: PlaybackStatus.PAUSED,
          currentTrackStartedAt: null,
          pausedPlaybackPositionMs: 0,
        },
      });
    });
  }

  async endEvent(eventId: string) {
    return this.prisma.event.update({
      where: { id: eventId },
      data: { status: EventStatus.ENDED },
    });
  }

  async pausePlayback(eventId: string, position: number) {
    return this.prisma.event.update({
      where: { id: eventId },
      data: {
        playbackStatus: PlaybackStatus.PAUSED,
        currentTrackStartedAt: null,
        pausedPlaybackPositionMs: position,
      },
    });
  }

  async findInvitedUsers(eventId: string, pagination: PaginationDto) {
    const { page = 1, limit = 20 } = pagination;
    const skip = (page - 1) * limit;

    const [invites, total] = await Promise.all([
      this.prisma.eventInvite.findMany({
        where: { eventId },
        skip,
        take: limit,
        select: {
          user: {
            select: {
              id: true,
              username: true,
              avatarUrl: true,
            },
          },
        },
      }),
      this.prisma.eventInvite.count({ where: { eventId } }),
    ]);

    return {
      data: invites.map((i) => i.user),
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }
}
