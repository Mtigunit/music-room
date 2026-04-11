import { Injectable } from '@nestjs/common';
import { CreateEventDto } from './dto/create-event.dto';
import { UpdateEventDto } from './dto/update-event.dto';
import { EventsRepository } from './events.repository';

@Injectable()
export class EventsService {
  constructor(private readonly eventsRepository: EventsRepository) {}

  create(createEventDto: CreateEventDto) {
    return this.eventsRepository.create(createEventDto);
  }

  findAll() {
    return this.eventsRepository.findAll();
  }

  findOne(id: number) {
    return this.eventsRepository.findOne(id);
  }

  update(id: number, updateEventDto: UpdateEventDto) {
    return this.eventsRepository.update(id, updateEventDto);
  }

  remove(id: number) {
    return this.eventsRepository.remove(id);
  }
}
