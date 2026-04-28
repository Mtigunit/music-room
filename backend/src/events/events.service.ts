import { EventEmitter2 } from '@nestjs/event-emitter';
import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import { CreateEventDto } from './dto/create-event.dto';
import { UpdateEventDto } from './dto/update-event.dto';
import { EventsRepository } from './events.repository';
import { EventsGateway } from './events.gateway';
import { AUDIT_LOG_EVENT, AuditAction } from '../audit-log/audit-log.constants';
import { createAuditLogEvent } from '../audit-log/audit-log.event';
import { YoutubeService } from '../tracks/youtube.service';
import { Visibility } from '@prisma/client';
import { TrackSearchResultDto } from '../tracks/dto/track-search-result.dto';
import { ClientMetaDto } from '../common/dto/client-meta.dto';

@Injectable()
export class EventsService {
  constructor(
    private readonly eventsRepository: EventsRepository,
    private readonly eventsGateway: EventsGateway,
    private readonly youtubeService: YoutubeService,
    private readonly eventEmitter: EventEmitter2,
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
    const event = await this.eventsRepository.findByIdWithDetails(id);
    if (!event) {
      throw new NotFoundException(`Event with ID ${id} not found`);
    }

    const { tracks, host, invites, ...eventData } = event;
    if (
      event.visibility === Visibility.PRIVATE &&
      event.hostId !== userId &&
      !invites.some((i: { userId: string }) => i.userId === userId)
    ) {
      throw new ForbiddenException(
        'Forbidden: You do not have access to this event',
      );
    }

    return {
      ...eventData,
      host: host ? { id: host.id, name: host.username } : null,
      tracks,
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

    const roomName = `event_${eventId}`;
    this.eventsGateway.server.to(roomName).emit('track:add', newTrack);

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
    this.eventsGateway.server
      .to(roomName)
      .emit('track:remove', { providerTrackId: result.providerTrackId });

    this.eventEmitter.emit(
      AUDIT_LOG_EVENT,
      createAuditLogEvent(userId, AuditAction.EVENT_TRACK_REMOVE, meta, {
        eventId,
        trackId: providerTrackId,
      }),
    );

    return result;
  }
}
