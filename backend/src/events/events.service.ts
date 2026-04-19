import { Injectable } from '@nestjs/common';
import { CreateEventDto } from './dto/create-event.dto';
import { UpdateEventDto } from './dto/update-event.dto';
import { AppendedTrackDto } from './dto/append-tracks.dto';
import { EventsRepository } from './events.repository';

@Injectable()
export class EventsService {
  constructor(private readonly eventsRepository: EventsRepository) {}

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

  appendTracks(id: string, userId: string, tracks: AppendedTrackDto[]) {
    return this.eventsRepository.appendTracks(id, userId, tracks);
  }

  inviteUser(eventId: string, hostId: string, invitedUserId: string) {
    return this.eventsRepository.inviteUser(eventId, hostId, invitedUserId);
  }

  remove(id: string, userId: string) {
    return this.eventsRepository.remove(id, userId);
  }
}
