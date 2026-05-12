import { EventEmitter2 } from '@nestjs/event-emitter';
import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  ConflictException,
  BadRequestException,
  forwardRef,
  Inject,
} from '@nestjs/common';
import { CreateEventDto } from './dto/create-event.dto';
import { UpdateEventDto } from './dto/update-event.dto';
import { EventsRepository } from './events.repository';
import { EventsGateway } from './events.gateway';
import { AUDIT_LOG_EVENT, AuditAction } from '../audit-log/audit-log.constants';
import { createAuditLogEvent } from '../audit-log/audit-log.event';
import { YoutubeService } from '../tracks/youtube.service';
import {
  EventStatus,
  PlaybackStatus,
  PolicyType,
  Visibility,
  NotificationType,
} from '@prisma/client';
import { TrackSearchResultDto } from '../tracks/dto/track-search-result.dto';
import { ClientMetaDto } from '../common/dto/client-meta.dto';
import { REDIS_KEYS, BULL_JOBS, BULL_QUEUES } from './events.constants';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { RedisService } from '../redis/redis.service';
import { WS_EVENTS } from './events.constants';
import { NOTIFICATION_TRIGGER_EVENT } from '../notifications/notifications.constants';
import type { NotificationTriggerEvent } from '../notifications/notifications.event';
import { NotificationPayloadType } from '../notifications/dto/notification-payload.dto';

export function getPosition(event: {
  playbackStatus: PlaybackStatus;
  currentTrackStartedAt: Date | null;
  pausedPlaybackPositionMs: number | null;
}): number {
  if (
    event.playbackStatus === PlaybackStatus.PAUSED ||
    !event.currentTrackStartedAt
  ) {
    return event.pausedPlaybackPositionMs ?? 0;
  }
  return (
    Date.now() -
    new Date(event.currentTrackStartedAt).getTime() +
    (event.pausedPlaybackPositionMs ?? 0)
  );
}

/**
 * Asserts that a user is authorised to control playback for the given event.
 *
 * Rules (evaluated in order):
 *  1. The event host always passes — no DB call is made.
 *  2. Any other user must hold an active delegation for this event.
 *  3. When a `deviceId` is supplied the delegation must be bound to that same device.
 *
 * @throws ForbiddenException – no active delegation found, or delegation device mismatch.
 */
async function checkPlaybackDelegation(
  eventsRepository: EventsRepository,
  event: { id: string; hostId: string },
  userId: string,
  deviceId: string,
): Promise<void> {
  if (event.hostId === userId) return;

  const delegation = await eventsRepository.findActiveDelegation(
    event.id,
    userId,
  );

  if (!delegation) {
    throw new ForbiddenException('You are not permitted to control playback');
  }

  if (deviceId === 'unknown')
    throw new ForbiddenException('A valid device ID is required');

  if (deviceId && delegation.deviceId !== deviceId)
    throw new ForbiddenException('Control delegation not valid on this device');
}

@Injectable()
export class EventsService {
  constructor(
    private readonly eventsRepository: EventsRepository,
    @Inject(forwardRef(() => EventsGateway))
    private readonly eventsGateway: EventsGateway,
    private readonly youtubeService: YoutubeService,
    private readonly eventEmitter: EventEmitter2,
    private readonly redisService: RedisService,
    @InjectQueue(BULL_QUEUES.EVENT_TIMEOUTS)
    private readonly eventTimeoutsQueue: Queue,
  ) {}

  async create(
    userId: string,
    createEventDto: CreateEventDto,
    meta: ClientMetaDto,
  ) {
    const { playlistIds, tracks } = createEventDto;

    if (playlistIds && playlistIds.length > 0) {
      const uniquePlaylistIds = Array.from(new Set(playlistIds));
      const playlists = await this.eventsRepository.findPlaylistsByIds(
        uniquePlaylistIds,
        userId,
      );
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

    let fetchedTracks: TrackSearchResultDto[] = [];
    if (tracks && tracks.length > 0) {
      const uniqueProviderTrackIds = Array.from(new Set(tracks));
      const metadata = await this.youtubeService.getTrackDetailsBatch(
        uniqueProviderTrackIds,
      );
      fetchedTracks = metadata.filter(
        (t): t is TrackSearchResultDto => t !== null,
      );
    }

    const event = await this.eventsRepository.createEvent(
      userId,
      createEventDto,
      fetchedTracks,
    );

    this.eventEmitter.emit(
      AUDIT_LOG_EVENT,
      createAuditLogEvent(userId, AuditAction.EVENT_CREATE, meta, {
        eventId: event.id,
      }),
    );

    return event;
  }

  findAll(
    userId: string,
    options: { page: number; limit: number; search?: string },
  ) {
    return this.eventsRepository.findAll(userId, options);
  }

  findHosting(
    userId: string,
    options: { page: number; limit: number; search?: string },
  ) {
    return this.eventsRepository.findHosting(userId, options);
  }

  findInvited(
    userId: string,
    options: { page: number; limit: number; search?: string },
  ) {
    return this.eventsRepository.findInvited(userId, options);
  }

  async findOne(id: string, userId: string) {
    const event = await this.eventsRepository.findByIdWithDetails(id, userId);
    if (!event) {
      throw new NotFoundException(`Event with ID ${id} not found`);
    }

    const {
      tracks,
      host,
      invites,
      policies,
      invitingOnly,
      hostId,
      delegations,
      currentTrackId,
      ...eventData
    } = event;

    if (
      event.visibility === Visibility.PRIVATE &&
      event.hostId !== userId &&
      !invites.length
    ) {
      throw new ForbiddenException(
        'Forbidden: You do not have access to this event',
      );
    }

    const timeWindowPolicy = policies?.find(
      (p) => p.policyType === PolicyType.TIME_WINDOW,
    );

    let startDate: Date | undefined;
    let endDate: Date | undefined;

    if (timeWindowPolicy?.config) {
      const config = timeWindowPolicy.config as {
        startDate: string;
        endDate: string;
      };
      if (config.startDate) startDate = new Date(config.startDate);
      if (config.endDate) endDate = new Date(config.endDate);
    }

    const currentTrack =
      await this.eventsRepository.getCurrentTrackPayload(currentTrackId);

    return {
      ...eventData,
      host: host ? { id: hostId, name: host.username } : null,
      tracks,
      currentTrack:
        currentTrack === null
          ? null
          : {
              ...currentTrack,
              currentTrackStartedAt: event.currentTrackStartedAt,
              pausedPlaybackPositionMs: event.pausedPlaybackPositionMs,
            },
      isInvited: (invites?.length ?? 0) > 0,
      isHost: event.hostId === userId,
      isDelegated: (delegations?.length ?? 0) > 0,
      policies: {
        locationAndTime: (policies?.length ?? 0) > 0,
        invitingOnly,
        ...(startDate && { startDate }),
        ...(endDate && { endDate }),
      },
    };
  }

  async update(
    id: string,
    userId: string,
    updateEventDto: UpdateEventDto,
    meta: ClientMetaDto,
  ) {
    const existingEvent = await this.eventsRepository.findById(id);
    if (!existingEvent) {
      throw new NotFoundException(`Event with ID ${id} not found`);
    }
    if (existingEvent.hostId !== userId) {
      throw new ForbiddenException(
        `You are not authorized to update this event`,
      );
    }

    const { playlistIds, tracks } = updateEventDto;
    if (playlistIds && playlistIds.length > 0) {
      const uniquePlaylistIds = Array.from(new Set(playlistIds));
      const playlists = await this.eventsRepository.findPlaylistsByIds(
        uniquePlaylistIds,
        userId,
      );
      if (playlists.length !== uniquePlaylistIds.length) {
        const foundIds = playlists.map((p) => p.id);
        const missingIds = uniquePlaylistIds.filter(
          (pId) => !foundIds.includes(pId),
        );
        throw new NotFoundException(
          `Playlists not found: ${missingIds.join(', ')}`,
        );
      }
    }

    let fetchedTracks: TrackSearchResultDto[] = [];
    if (tracks && tracks.length > 0) {
      const uniqueProviderTrackIds = Array.from(new Set(tracks));
      const metadata = await this.youtubeService.getTrackDetailsBatch(
        uniqueProviderTrackIds,
      );
      fetchedTracks = metadata.filter(
        (t): t is TrackSearchResultDto => t !== null,
      );
    }

    const result = await this.eventsRepository.updateEvent(
      id,
      userId,
      updateEventDto,
      fetchedTracks,
    );

    this.eventEmitter.emit(
      AUDIT_LOG_EVENT,
      createAuditLogEvent(userId, AuditAction.EVENT_UPDATE, meta, {
        eventId: id,
        update: updateEventDto,
      }),
    );

    return result;
  }

  async inviteUser(
    eventId: string,
    hostId: string,
    invitedUserId: string,
    meta: ClientMetaDto,
  ) {
    const event = await this.eventsRepository.findById(eventId);
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

    const userToInvite =
      await this.eventsRepository.findUserById(invitedUserId);
    if (!userToInvite) {
      throw new NotFoundException(`User with ID ${invitedUserId} not found`);
    }

    const existingInvite = await this.eventsRepository.findInvite(
      eventId,
      invitedUserId,
    );
    if (existingInvite) {
      throw new ConflictException('User is already invited to this event');
    }

    const result = await this.eventsRepository.createInvite(
      eventId,
      invitedUserId,
    );

    this.eventEmitter.emit(
      AUDIT_LOG_EVENT,
      createAuditLogEvent(hostId, AuditAction.EVENT_INVITE, meta, {
        eventId,
        invitedUserId,
      }),
    );

    const notificationEvent: NotificationTriggerEvent = {
      recipientId: invitedUserId,
      type: NotificationType.EVENT_INVITE,
      payload: {
        payloadType: NotificationPayloadType.EVENT,
        id: eventId,
        meta: { eventName: event.name },
      },
      context: { eventName: event.name },
    };
    this.eventEmitter.emit(NOTIFICATION_TRIGGER_EVENT, notificationEvent);

    return result;
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
        'page must be an integer greater than or equal to 1',
      );
    }
    if (!Number.isInteger(limit) || limit < 1) {
      throw new BadRequestException(
        'limit must be an integer greater than or equal to 1',
      );
    }
    if (limit > MAX_PAGE_SIZE) {
      throw new BadRequestException(
        `\`limit\` must be less than or equal to ${MAX_PAGE_SIZE}`,
      );
    }

    const event = await this.eventsRepository.findByIdWithInvites(id);
    if (!event) {
      throw new NotFoundException(`Event with ID ${id} not found`);
    }

    if (
      event.visibility !== Visibility.PUBLIC &&
      event.hostId !== userId &&
      !event.invites.some((i: { userId: string }) => i.userId === userId)
    ) {
      throw new ForbiddenException(
        'You do not have permission to view tracks for this event',
      );
    }

    const skip = (page - 1) * limit;
    const { tracks, total } = await this.eventsRepository.getTracks(
      id,
      skip,
      limit,
      userId,
    );

    return {
      data: tracks,
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async remove(id: string, userId: string, meta: ClientMetaDto) {
    const event = await this.eventsRepository.findById(id);
    if (!event) {
      throw new NotFoundException(`Event with ID ${id} not found`);
    }
    if (event.hostId !== userId) {
      throw new ForbiddenException('Only the host can delete this event');
    }

    await this.eventsRepository.deleteEvent(id);

    this.eventEmitter.emit(
      AUDIT_LOG_EVENT,
      createAuditLogEvent(userId, AuditAction.EVENT_DELETE, meta, {
        eventId: id,
      }),
    );

    return { message: 'Event successfully deleted' };
  }

  async appendTrack(
    eventId: string,
    userId: string,
    providerTrackId: string,
    meta: ClientMetaDto,
  ) {
    const event = await this.eventsRepository.findByIdWithInvites(eventId);
    if (!event) {
      throw new NotFoundException(`Event with ID ${eventId} not found`);
    }

    if (
      event.visibility !== Visibility.PUBLIC &&
      event.hostId !== userId &&
      !event.invites.some((i: { userId: string }) => i.userId === userId)
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

    const track = await this.eventsRepository.upsertTrackAndGet({
      providerTrackId: trackDetails.providerTrackId,
      title: trackDetails.title,
      artist: trackDetails.artist || '',
      durationMs: trackDetails.durationMs,
      thumbnailUrl: trackDetails.thumbnailUrl || '',
    });

    const existingEventTrack = await this.eventsRepository.findEventTrack(
      eventId,
      track.id,
    );
    if (existingEventTrack) {
      throw new ConflictException(
        `Track is already attached to this event: ${track.providerTrackId}`,
      );
    }

    const newTrack = await this.eventsRepository.createEventTrack(
      eventId,
      track.id,
      userId,
    );

    if (event.currentTrackId === null && event.status === EventStatus.LIVE) {
      await this.eventsRepository.setInitialTrack(eventId, newTrack.id);
      this.eventsGateway.server
        .to(`event_${eventId}`)
        .emit(WS_EVENTS.PLAYBACK_STATUS, {
          status: PlaybackStatus.PAUSED,
          currentTrack: {
            id: newTrack.id,
            providerTrackId: newTrack.track.providerTrackId,
            title: newTrack.track.title,
            artist: newTrack.track.artist,
            durationMs: newTrack.track.durationMs,
            thumbnailUrl: newTrack.track.thumbnailUrl,
            pausedPlaybackPositionMs: 0,
            currentTrackStartedAt: null,
          },
        });
    }

    const roomName = `event_${eventId}`;
    this.eventsGateway.server
      .to(roomName)
      .emit(WS_EVENTS.TRACK_ADDED, newTrack);

    this.eventEmitter.emit(
      AUDIT_LOG_EVENT,
      createAuditLogEvent(userId, AuditAction.EVENT_TRACK_ADD, meta, {
        eventId,
        trackId: providerTrackId,
      }),
    );

    return newTrack;
  }

  async removeTrack(
    eventId: string,
    providerTrackId: string,
    userId: string,
    meta: ClientMetaDto,
  ) {
    const event = await this.eventsRepository.findById(eventId);
    if (!event) {
      throw new NotFoundException(`Event with ID ${eventId} not found`);
    }

    const eventTrack = await this.eventsRepository.findEventTrackByProviderId(
      eventId,
      providerTrackId,
    );
    if (!eventTrack) {
      throw new NotFoundException(
        `Track with provider ID ${providerTrackId} not found in event`,
      );
    }

    if (event.currentTrackId === eventTrack.id) {
      throw new BadRequestException(
        'Cannot remove a track that is currently playing',
      );
    }

    if (event.hostId !== userId && eventTrack.addedById !== userId) {
      throw new ForbiddenException(
        'Only the event host or the user who added this track can remove it',
      );
    }

    await this.eventsRepository.deleteEventTrack(eventTrack.id);

    const result = {
      trackId: eventTrack.trackId,
      providerTrackId: eventTrack.track.providerTrackId,
    };

    const roomName = `event_${eventId}`;
    this.eventsGateway.server.to(roomName).emit(WS_EVENTS.TRACK_REMOVED, {
      providerTrackId: result.providerTrackId,
    });

    this.eventEmitter.emit(
      AUDIT_LOG_EVENT,
      createAuditLogEvent(userId, AuditAction.EVENT_TRACK_REMOVE, meta, {
        eventId,
        trackId: providerTrackId,
      }),
    );

    return result;
  }

  async play(eventId: string, userId: string, deviceId: string) {
    const event = await this.eventsRepository.findById(eventId);
    if (!event) throw new NotFoundException('Event not found');

    await checkPlaybackDelegation(
      this.eventsRepository,
      event,
      userId,
      deviceId,
    );

    if (event.status !== EventStatus.LIVE)
      throw new BadRequestException('Event is not LIVE');

    const updatedEvent =
      await this.eventsRepository.updatePlaybackPlay(eventId);
    const currentTrack = await this.eventsRepository.getCurrentTrackPayload(
      updatedEvent.currentTrackId,
    );

    this.eventsGateway.server
      .to(`event_${eventId}`)
      .emit(WS_EVENTS.PLAYBACK_STATUS, {
        status: PlaybackStatus.PLAYING,
        currentTrack:
          currentTrack === null
            ? null
            : {
                ...currentTrack,
                currentTrackStartedAt: updatedEvent.currentTrackStartedAt,
                pausedPlaybackPositionMs: updatedEvent.pausedPlaybackPositionMs,
              },
      });

    return { status: PlaybackStatus.PLAYING };
  }

  async pause(eventId: string, userId: string, deviceId: string) {
    const event = await this.eventsRepository.findById(eventId);
    if (!event) throw new NotFoundException('Event not found');

    await checkPlaybackDelegation(
      this.eventsRepository,
      event,
      userId,
      deviceId,
    );

    if (event.status !== EventStatus.LIVE)
      throw new BadRequestException('Event is not LIVE');

    const positionMs = getPosition(event);
    const updatedEvent = await this.eventsRepository.updatePlaybackPause(
      eventId,
      positionMs,
    );
    const currentTrack = await this.eventsRepository.getCurrentTrackPayload(
      updatedEvent.currentTrackId,
    );

    this.eventsGateway.server
      .to(`event_${eventId}`)
      .emit(WS_EVENTS.PLAYBACK_STATUS, {
        status: PlaybackStatus.PAUSED,
        currentTrack:
          currentTrack === null
            ? null
            : {
                ...currentTrack,
                pausedPlaybackPositionMs: positionMs,
                currentTrackStartedAt: null,
              },
      });

    return { status: PlaybackStatus.PAUSED };
  }

  async next(
    eventId: string,
    userId: string,
    trackId: string | null,
    deviceId: string,
  ) {
    const event = await this.eventsRepository.findById(eventId);
    if (!event) throw new NotFoundException('Event not found');

    await checkPlaybackDelegation(
      this.eventsRepository,
      event,
      userId,
      deviceId,
    );

    if (trackId && event.currentTrackId !== trackId) {
      throw new ConflictException('Track mismatch—client state is stale');
    }

    const result = await this.eventsRepository.advanceQueue(eventId);
    if (!result) throw new NotFoundException('Event not found');

    const { event: updatedEvent, nextTrackId } = result;

    if (nextTrackId) {
      const currentTrack = await this.eventsRepository.getCurrentTrackPayload(
        updatedEvent.currentTrackId,
      );
      this.eventsGateway.server
        .to(`event_${eventId}`)
        .emit(WS_EVENTS.PLAYBACK_STATUS, {
          status: PlaybackStatus.PLAYING,
          currentTrack:
            currentTrack === null
              ? null
              : {
                  ...currentTrack,
                  currentTrackStartedAt: updatedEvent.currentTrackStartedAt,
                  pausedPlaybackPositionMs: 0,
                },
        });
    } else {
      this.eventsGateway.server
        .to(`event_${eventId}`)
        .emit(WS_EVENTS.PLAYBACK_STATUS, {
          status: PlaybackStatus.PAUSED,
          currentTrack: null,
        });
    }

    return { currentTrackId: updatedEvent.currentTrackId };
  }

  async startEvent(eventId: string, userId: string, socketId: string) {
    const existingLiveEvent =
      await this.eventsRepository.findByIdWithInvites(eventId);
    if (!existingLiveEvent) {
      throw new NotFoundException('Event not found');
    }
    if (existingLiveEvent.hostId !== userId) {
      throw new ForbiddenException('Only host can start the event');
    }
    if (existingLiveEvent.status === EventStatus.LIVE) {
      throw new ForbiddenException('Event is already live');
    }

    const hostHasOtherLiveEvent = await this.eventsRepository.findHostLiveEvent(
      userId,
      eventId,
    );
    if (hostHasOtherLiveEvent) {
      throw new ForbiddenException('Host already has another live event');
    }

    const updatedEvent = await this.eventsRepository.startEvent(eventId);

    const redisClient = this.redisService.getClient();
    await redisClient.set(REDIS_KEYS.EVENT_HOST(eventId), userId);
    await redisClient.set(REDIS_KEYS.HOST_SOCKET(eventId), socketId);

    const recipientIds = new Set<string>(
      existingLiveEvent.invites.map((invite) => invite.userId),
    );
    recipientIds.delete(existingLiveEvent.hostId);

    for (const recipientId of recipientIds) {
      const notificationEvent: NotificationTriggerEvent = {
        recipientId,
        type: NotificationType.EVENT_START,
        payload: {
          payloadType: NotificationPayloadType.EVENT,
          id: eventId,
          meta: { eventName: existingLiveEvent.name },
        },
        context: { eventName: existingLiveEvent.name },
      };
      this.eventEmitter.emit(NOTIFICATION_TRIGGER_EVENT, notificationEvent);
    }

    return updatedEvent;
  }

  async endEvent(eventId: string, userId: string) {
    const event = await this.eventsRepository.findById(eventId);
    if (!event) {
      throw new NotFoundException('Event not found');
    }
    if (event.hostId !== userId) {
      throw new ForbiddenException('Only host can end the event');
    }
    if (event.status !== EventStatus.LIVE) {
      throw new ForbiddenException('Event is not live');
    }

    await this.eventsRepository.endEvent(eventId);

    const redisClient = this.redisService.getClient();
    await redisClient.del(
      ...[
        REDIS_KEYS.EVENT_HOST(eventId),
        REDIS_KEYS.HOST_SOCKET(eventId),
        REDIS_KEYS.HOST_DISCONNECT(eventId),
      ],
    );

    return event;
  }

  async handleHostDisconnect(userId: string, socketId: string) {
    const liveEvent = await this.eventsRepository.findHostLiveEvent(userId);
    if (!liveEvent) {
      return null;
    }

    const redisClient = this.redisService.getClient();
    const hostSocketKey = REDIS_KEYS.HOST_SOCKET(liveEvent.id);
    const currentHostSocketId = await redisClient.get(hostSocketKey);

    if (currentHostSocketId === socketId) {
      await this.startHostGracePeriod(liveEvent.id, userId);

      const position = getPosition(liveEvent);
      await this.eventsRepository.pausePlayback(liveEvent.id, position);

      return {
        eventId: liveEvent.id,
        currentTrackId: liveEvent.currentTrackId,
        pausedPosition: position,
      };
    }

    return null;
  }

  async startHostGracePeriod(eventId: string, userId: string) {
    const redisClient = this.redisService.getClient();
    await redisClient.set(REDIS_KEYS.HOST_DISCONNECT(eventId), userId);

    await this.eventTimeoutsQueue.add(
      BULL_JOBS.HOST_SOFT_TIMEOUT,
      { eventId, userId },
      {
        jobId: `soft-${eventId}`,
        delay: BULL_JOBS.SOFT_TIMEOUT,
      },
    );

    await this.eventTimeoutsQueue.add(
      BULL_JOBS.HOST_HARD_TIMEOUT,
      { eventId, userId },
      {
        jobId: `hard-${eventId}`,
        delay: BULL_JOBS.HARD_TIMEOUT,
      },
    );
  }
}
