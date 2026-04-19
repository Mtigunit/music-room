import { Test, TestingModule } from '@nestjs/testing';
import { EventsController } from './events.controller';
import { EventsService } from './events.service';
import { EventsRepository } from './events.repository';
import { PrismaService } from '../prisma/prisma.service';

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
      const trackIds = ['a1b2c3d4-e5f6-4890-8bcd-ef1234567890'];
      const spy = jest
        .spyOn(service, 'appendTracks')
        .mockResolvedValue(undefined as any);

      await controller.appendTracks(eventId, { trackIds });

      expect(spy).toHaveBeenCalledWith(eventId, trackIds);
    });
  });
});
