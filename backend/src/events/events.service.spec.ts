import { Test, TestingModule } from '@nestjs/testing';
import { EventsService } from './events.service';
import { EventsRepository } from './events.repository';
import { PrismaService } from '../prisma/prisma.service';
import { SocketIoGateway } from '../websockets/socket-io.gateway';

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
        {
          provide: SocketIoGateway,
          useValue: {
            server: {
              to: jest.fn().mockReturnThis(),
              emit: jest.fn(),
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

      const spy = jest
        .spyOn(repository, 'getTracks')
        .mockResolvedValue([] as never);

      await service.getTracks(eventId, userId);

      expect(spy).toHaveBeenCalledWith(eventId, userId);
    });
  });
});
