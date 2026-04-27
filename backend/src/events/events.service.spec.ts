import { Test, TestingModule } from '@nestjs/testing';
import { EventsService } from './events.service';
import { EventsRepository } from './events.repository';
import { PrismaService } from '../prisma/prisma.service';
import { EventsGateway } from './events.gateway';
import { YoutubeService } from '../tracks/youtube.service';
import { EventEmitter2 } from '@nestjs/event-emitter';

describe('EventsService', () => {
  let service: EventsService;
  let repository: EventsRepository;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        EventsService,
        EventsRepository,
        {
          provide: YoutubeService,
          useValue: {
            getTrackDetails: jest.fn(),
          },
        },
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
        {
          provide: EventsGateway,
          useValue: {
            server: {
              to: jest.fn().mockReturnThis(),
              in: jest.fn().mockReturnThis(),
              socketsLeave: jest.fn(),
              emit: jest.fn(),
            },
          },
        },
        {
          provide: EventEmitter2,
          useValue: { emit: jest.fn() },
        },
      ],
    }).compile();

    service = module.get<EventsService>(EventsService);
    repository = module.get<EventsRepository>(EventsRepository);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('inviteUser', () => {
    it('should call eventsRepository.inviteUser with correct parameters', async () => {
      const eventId = '740777df-e348-40b6-925e-4c0f020cf68c';
      const hostId = 'user-1';
      const invitedUserId = 'user-2';

      const spy = jest
        .spyOn(repository, 'inviteUser')
        .mockResolvedValue({ id: 'invite-1' } as never);

      await service.inviteUser(eventId, hostId, invitedUserId);

      expect(spy).toHaveBeenCalledWith(eventId, hostId, invitedUserId);
    });
  });

  describe('getTracks', () => {
    it('should call eventsRepository.getTracks with correct parameters', async () => {
      const eventId = '740777df-e348-40b6-925e-4c0f020cf68c';
      const userId = 'user-1';
      const options = { page: 1, limit: 10 };

      const spy = jest.spyOn(repository, 'getTracks').mockResolvedValue({
        data: [],
        pagination: { total: 0, page: 1, limit: 10, totalPages: 0 },
      } as never);

      await service.getTracks(eventId, userId, options);

      expect(spy).toHaveBeenCalledWith(eventId, userId, options);
    });
  });
});
