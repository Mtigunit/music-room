import { Injectable } from '@nestjs/common';
import { CreateEventDto } from './dto/create-event.dto';
import { UpdateEventDto } from './dto/update-event.dto';
import { EventsRepository } from './events.repository';
import { SocketIoGateway } from '../websockets/socket-io.gateway';

@Injectable()
export class EventsService {
  constructor(
    private readonly eventsRepository: EventsRepository,
    private readonly socketIoGateway: SocketIoGateway,
  ) {}

  create(userId: string, createEventDto: CreateEventDto) {
    return this.eventsRepository.create(userId, createEventDto);
  }

  explore(
    userId: string,
    options: { page: number; limit: number; search?: string },
  ) {
    return this.eventsRepository.explore(userId, options);
  }

  findAll(
    userId: string,
    options: { page: number; limit: number; search?: string },
  ) {
    return this.eventsRepository.findAll(userId, options);
  }

  findOne(id: string) {
    return this.eventsRepository.findOne(id);
  }

  update(id: string, userId: string, updateEventDto: UpdateEventDto) {
    return this.eventsRepository.update(id, userId, updateEventDto);
  }

  inviteUser(eventId: string, hostId: string, invitedUserId: string) {
    return this.eventsRepository.inviteUser(eventId, hostId, invitedUserId);
  }

  getTracks(id: string, userId: string) {
    return this.eventsRepository.getTracks(id, userId);
  }

  remove(id: string, userId: string) {
    return this.eventsRepository.remove(id, userId);
  }

  async appendTrack(
    eventId: string,
    userId: string,
    providerTrackIds: string[],
  ) {
    const newTracks = await this.eventsRepository.appendTrack(
      eventId,
      userId,
      providerTrackIds,
    );

    for (const newTrack of newTracks) {
      this.socketIoGateway.server.to(eventId).emit('track:added', newTrack);
    }

    return newTracks;
  }

  async removeTrack(eventId: string, providerTrackId: string, userId: string) {
    const result = await this.eventsRepository.removeTrack(
      eventId,
      providerTrackId,
      userId,
    );
    this.socketIoGateway.server
      .to(eventId)
      .emit('track:removed', { providerTrackId: result.providerTrackId });
    return result;
  }
}
