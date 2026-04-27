import { Test, TestingModule } from '@nestjs/testing';
import { EventsService } from './events.service';
import { EventsRepository } from './events.repository';
import { EventsGateway } from './events.gateway';
import { YoutubeService } from '../tracks/youtube.service';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { Visibility } from '@prisma/client';

describe('EventsService', () => {
  let service: EventsService;
  let repository: EventsRepository;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        EventsService,
        {
          provide: EventsRepository,
          useValue: {
            findById: jest.fn(),
            findUserById: jest.fn(),
            findInvite: jest.fn(),
            createInvite: jest.fn(),
            findByIdWithInvites: jest.fn(),
            getTracks: jest.fn(),
          },
        },
        {
          provide: YoutubeService,
          useValue: {
            getTrackDetails: jest.fn(),
            getTrackDetailsBatch: jest.fn(),
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
    it('should correctly invite a user when all checks pass', async () => {
      const eventId = '740777df-e348-40b6-925e-4c0f020cf68c';
      const hostId = 'user-1';
      const invitedUserId = 'user-2';

      jest
        .spyOn(repository, 'findById')
        .mockResolvedValue({ id: eventId, hostId } as any);
      jest
        .spyOn(repository, 'findUserById')
        .mockResolvedValue({ id: invitedUserId } as any);
      jest.spyOn(repository, 'findInvite').mockResolvedValue(null);
      const createInviteSpy = jest
        .spyOn(repository, 'createInvite')
        .mockResolvedValue({
          id: 'invite-1',
          eventId,
          userId: invitedUserId,
          createdAt: new Date(),
        } as any);

      await service.inviteUser(eventId, hostId, invitedUserId);

      expect(repository.findById).toHaveBeenCalledWith(eventId);
      expect(repository.findUserById).toHaveBeenCalledWith(invitedUserId);
      expect(repository.findInvite).toHaveBeenCalledWith(
        eventId,
        invitedUserId,
      );
      expect(createInviteSpy).toHaveBeenCalledWith(eventId, invitedUserId);
    });
  });

  describe('getTracks', () => {
    it('should correctly return tracks for an event when user is allowed', async () => {
      const eventId = '740777df-e348-40b6-925e-4c0f020cf68c';
      const userId = 'user-1';
      const options = { page: 1, limit: 10 };

      jest.spyOn(repository, 'findByIdWithInvites').mockResolvedValue({
        id: eventId,
        visibility: Visibility.PUBLIC,
        hostId: 'some-other-host',
        invites: [],
      } as any);

      const getTracksSpy = jest
        .spyOn(repository, 'getTracks')
        .mockResolvedValue({
          tracks: [],
          total: 0,
        } as never);

      await service.getTracks(eventId, userId, options);

      expect(repository.findByIdWithInvites).toHaveBeenCalledWith(eventId);
      expect(getTracksSpy).toHaveBeenCalledWith(eventId, 0, 10);
    });
  });
});
