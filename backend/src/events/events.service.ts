import { Injectable } from '@nestjs/common';
import { CreateEventDto } from './dto/create-event.dto';
import { UpdateEventDto } from './dto/update-event.dto';
import { EventsRepository } from './events.repository';

@Injectable()
export class EventsService {
  constructor(private readonly eventsRepository: EventsRepository) {}

  create(userId: string, createEventDto: CreateEventDto) {
    return this.eventsRepository.create(userId, createEventDto);
  }

  findAll() {
    return this.eventsRepository.findAll();
  }

  findOne(id: string) {
    return this.eventsRepository.findOne(id);
  }

  update(id: string, updateEventDto: UpdateEventDto) {
    return this.eventsRepository.update(id, updateEventDto);
  }

  appendTracks(id: string, trackIds: string[]) {
    return this.eventsRepository.appendTracks(id, trackIds);
  }

  remove(id: string) {
    return this.eventsRepository.remove(id);
  }
}
