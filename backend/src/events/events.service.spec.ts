import { Test, TestingModule } from '@nestjs/testing';
import { EventsService } from './events.service';
import { EventsRepository } from './events.repository';
import { PrismaService } from '../prisma/prisma.service';

describe('EventsService', () => {
  let service: EventsService;
  let repository: EventsRepository;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
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

    service = module.get<EventsService>(EventsService);
    repository = module.get<EventsRepository>(EventsRepository);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('appendTracks', () => {
    it('should call eventsRepository.appendTracks with correct parameters', async () => {
      const eventId = '740777df-e348-40b6-925e-4c0f020cf68c';
      const trackIds = ['a1b2c3d4-e5f6-4890-8bcd-ef1234567890'];
      const spy = jest
        .spyOn(repository, 'appendTracks')
        .mockResolvedValue(undefined as any);

      await service.appendTracks(eventId, trackIds);

      expect(spy).toHaveBeenCalledWith(eventId, trackIds);
    });
  });
});
