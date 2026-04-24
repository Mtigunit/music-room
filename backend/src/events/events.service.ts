import { Injectable } from '@nestjs/common';
import { CreateEventDto } from './dto/create-event.dto';
import { UpdateEventDto } from './dto/update-event.dto';
import { EventsRepository } from './events.repository';
import { EventsGateway } from './events.gateway';

@Injectable()
export class EventsService {
  constructor(
    private readonly eventsRepository: EventsRepository,
    private readonly eventsGateway: EventsGateway,
  ) {}

  create(userId: string, createEventDto: CreateEventDto) {
    return this.eventsRepository.create(userId, createEventDto);
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
    this.eventsGateway.server.to(roomName).emit('track:added', newTrack);

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
      .emit('track:removed', { providerTrackId: result.providerTrackId });
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
    this.eventsGateway.server.to(roomName).emit('event:ended', { eventId });
    this.eventsGateway.server.in(roomName).socketsLeave(roomName);

    return event;
  }
}
