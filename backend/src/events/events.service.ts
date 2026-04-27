import { Injectable } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { CreateEventDto } from './dto/create-event.dto';
import { UpdateEventDto } from './dto/update-event.dto';
import { EventsRepository } from './events.repository';
import { EventsGateway } from './events.gateway';
import { AUDIT_LOG_EVENT, AuditAction } from '../audit-log/audit-log.constants';
import type { AuditLogEvent } from '../audit-log/audit-log.event';

@Injectable()
export class EventsService {
  constructor(
    private readonly eventsRepository: EventsRepository,
    private readonly eventsGateway: EventsGateway,
    private readonly eventEmitter: EventEmitter2,
  ) {}

  async create(userId: string, createEventDto: CreateEventDto) {
    const event = await this.eventsRepository.create(userId, createEventDto);

    this.eventEmitter.emit(AUDIT_LOG_EVENT, {
      userId,
      action: AuditAction.EVENT_CREATE,
      platform: 'unknown',
      deviceModel: 'unknown',
      appVersion: 'unknown',
      metadata: { eventId: event.id },
    } satisfies AuditLogEvent);

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

  findOne(id: string, userId: string) {
    return this.eventsRepository.findOne(id, userId);
  }

  update(id: string, userId: string, updateEventDto: UpdateEventDto) {
    return this.eventsRepository.update(id, userId, updateEventDto);
  }

  inviteUser(eventId: string, hostId: string, invitedUserId: string) {
    return this.eventsRepository.inviteUser(eventId, hostId, invitedUserId);
  }

  getTracks(
    id: string,
    userId: string,
    options: { page: number; limit: number },
  ) {
    return this.eventsRepository.getTracks(id, userId, options);
  }

  remove(id: string, userId: string) {
    return this.eventsRepository.remove(id, userId);
  }

  async appendTrack(eventId: string, userId: string, providerTrackId: string) {
    const newTrack = await this.eventsRepository.appendTrack(
      eventId,
      userId,
      providerTrackId,
    );

    const roomName = `event_${eventId}`;
    this.eventsGateway.server.to(roomName).emit('track:add', newTrack);

    this.eventEmitter.emit(AUDIT_LOG_EVENT, {
      userId,
      action: AuditAction.EVENT_TRACK_ADD,
      platform: 'unknown',
      deviceModel: 'unknown',
      appVersion: 'unknown',
      metadata: { eventId, trackId: providerTrackId },
    } satisfies AuditLogEvent);

    return newTrack;
  }

  async removeTrack(eventId: string, providerTrackId: string, userId: string) {
    const result = await this.eventsRepository.removeTrack(
      eventId,
      providerTrackId,
      userId,
    );
    const roomName = `event_${eventId}`;
    this.eventsGateway.server
      .to(roomName)
      .emit('track:remove', { providerTrackId: result.providerTrackId });

    this.eventEmitter.emit(AUDIT_LOG_EVENT, {
      userId,
      action: AuditAction.EVENT_TRACK_REMOVE,
      platform: 'unknown',
      deviceModel: 'unknown',
      appVersion: 'unknown',
      metadata: { eventId, trackId: providerTrackId },
    } satisfies AuditLogEvent);

    return result;
  }

  async startEvent(eventId: string, userId: string) {
    const event = await this.eventsRepository.startEvent(eventId, userId);

    const roomName = `event_${eventId}`;
    this.eventsGateway.server.to(roomName).emit('event:started', { eventId });
    return event;
  }

  async endEvent(eventId: string, userId: string) {
    const event = await this.eventsRepository.endEvent(eventId, userId);

    const roomName = `event_${eventId}`;
    this.eventsGateway.server.to(roomName).emit('event:end', { eventId });
    this.eventsGateway.server.in(roomName).socketsLeave(roomName);

    return event;
  }
}
