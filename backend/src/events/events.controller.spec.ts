import { Test, TestingModule } from '@nestjs/testing';
import { EventsController } from './events.controller';
import { EventsService } from './events.service';
import { EventsRepository } from './events.repository';
import { PrismaService } from '../prisma/prisma.service';
import { AppendTracksDto } from './dto/append-tracks.dto';
import type { Request } from 'express';

describe('EventsController', () => {
  let controller: EventsController;
  let service: EventsService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [EventsController],
      providers: [
        EventsService,
        EventsRepository,
        {
          provide: PrismaService,
          useValue: {
            $transaction: jest.fn(),
            event: {
              create: jest.fn(),
              findMany: jest.fn(),
              findUnique: jest.fn(),
              update: jest.fn(),
              delete: jest.fn(),
            },
          },
        },
      ],
    }).compile();

    controller = module.get<EventsController>(EventsController);
    service = module.get<EventsService>(EventsService);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  describe('appendTracks', () => {
    it('should call eventsService.appendTracks with correct parameters', async () => {
      const eventId = '740777df-e348-40b6-925e-4c0f020cf68c';
      const tracks = [
        {
          providerTrackId: 'zaGHlRk1Aq0',
          title: 'A MESSAGE TO DIE FOR',
          durationMs: 362000,
        },
      ];
      const spy = jest
        .spyOn(service, 'appendTracks')
        .mockResolvedValue(undefined as never);

      await controller.appendTracks(eventId, { tracks } as AppendTracksDto);

      expect(spy).toHaveBeenCalledWith(eventId, tracks);
    });
  });

  describe('inviteUser', () => {
    it('should call eventsService.inviteUser with correct parameters', async () => {
      const eventId = '740777df-e348-40b6-925e-4c0f020cf68c';
      const hostId = 'user-1';
      const invitedUserId = 'user-2';
      const dto = { userId: invitedUserId };

      const req = { user: { id: hostId } } as unknown as Request;

      const spy = jest
        .spyOn(service, 'inviteUser')
        .mockResolvedValue({ id: 'invite-1' } as never);

      await controller.inviteUser(eventId, dto, req);

      expect(spy).toHaveBeenCalledWith(eventId, hostId, invitedUserId);
    });
  });
});
