import { Test, TestingModule } from '@nestjs/testing';
import { EventsService } from './events.service';
import { EventsRepository } from './events.repository';
import { EventsGateway } from './events.gateway';
import { YoutubeService } from '../tracks/youtube.service';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { NotificationType, Visibility } from '@prisma/client';
import { ForbiddenException, ConflictException } from '@nestjs/common';
import { RedisService } from '../redis/redis.service';
import { BULL_QUEUES } from './events.constants';
import { getQueueToken } from '@nestjs/bullmq';
import { NOTIFICATION_TRIGGER_EVENT } from '../notifications/notifications.constants';
import { NotificationPayloadType } from '../notifications/dto/notification-payload.dto';

describe('EventsService', () => {
  let service: EventsService;
  let repository: EventsRepository;
  let youtubeService: YoutubeService;
  let eventEmitter: jest.Mocked<EventEmitter2>;

  const mockMeta = {
    ipAddress: '127.0.0.1',
    platform: 'test',
    deviceModel: 'test',
    deviceId: 'test',
    appVersion: '1.0.0',
  } as any;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        EventsService,
        {
          provide: EventsRepository,
          useValue: {
            findById: jest.fn(),
            findByIdWithDetails: jest.fn(),
            findByIdWithInvites: jest.fn(),
            findUserById: jest.fn(),
            findInvite: jest.fn(),
            findPlaylistsByIds: jest.fn(),
            findEventTrack: jest.fn(),
            findEventTrackByProviderId: jest.fn(),
            createEvent: jest.fn(),
            createInvite: jest.fn(),
            createEventTrack: jest.fn(),
            updateEvent: jest.fn(),
            upsertTrackAndGet: jest.fn(),
            deleteEvent: jest.fn(),
            deleteEventTrack: jest.fn(),
            getTracks: jest.fn(),
            findAll: jest.fn(),
            findHosting: jest.fn(),
            findInvited: jest.fn(),
            getCurrentTrackPayload: jest.fn(),
            findActiveDelegation: jest.fn(),
            updatePlaybackPlay: jest.fn(),
            updatePlaybackPause: jest.fn(),
            advanceQueue: jest.fn(),
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
              emit: jest.fn(),
            },
          },
        },
        {
          provide: EventEmitter2,
          useValue: { emit: jest.fn() },
        },
        {
          provide: RedisService,
          useValue: {
            getClient: jest.fn(() => ({
              get: jest.fn(),
              set: jest.fn(),
              del: jest.fn(),
            })),
          },
        },
        {
          provide: getQueueToken(BULL_QUEUES.EVENT_TIMEOUTS),
          useValue: {
            add: jest.fn(),
            getJob: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get<EventsService>(EventsService);
    repository = module.get<EventsRepository>(EventsRepository);
    youtubeService = module.get<YoutubeService>(YoutubeService);
    eventEmitter = module.get(EventEmitter2);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('create', () => {
    it('should successfully create an event', async () => {
      const userId = 'user-1';
      const dto = { name: 'Test Event', tracks: ['track-1'] } as any;
      const mockTrack = { providerTrackId: 'track-1', title: 'Title' };

      jest
        .spyOn(youtubeService, 'getTrackDetailsBatch')
        .mockResolvedValue([mockTrack] as any);
      jest
        .spyOn(repository, 'createEvent')
        .mockResolvedValue({ id: 'event-1' } as any);

      const result = await service.create(userId, dto, mockMeta);

      expect(result.id).toBe('event-1');
      expect(repository.createEvent).toHaveBeenCalledWith(userId, dto, [
        mockTrack,
      ]);
    });
  });

  describe('findOne', () => {
    it('should return event details with host flags if user is host', async () => {
      const eventId = 'event-1';
      const userId = 'user-1';
      const mockEvent = {
        id: eventId,
        hostId: userId,
        visibility: Visibility.PUBLIC,
        tracks: [],
        invites: [],
        host: { id: userId, username: 'host' },
        currentTrackId: 'et-1',
      };

      jest
        .spyOn(repository, 'findByIdWithDetails')
        .mockResolvedValue(mockEvent as any);
      jest
        .spyOn(repository, 'getCurrentTrackPayload')
        .mockResolvedValue({ id: 'et-1', title: 'Track 1' } as any);

      const result = await service.findOne(eventId, userId);

      expect(result.id).toBe(eventId);
      expect(result.isHost).toBe(true);
      expect(result.isInvited).toBe(false);
      expect(result.currentTrack).toEqual({ id: 'et-1', title: 'Track 1' });
    });

    it('should return event details with invited flags if user is invited', async () => {
      const eventId = 'event-1';
      const userId = 'user-2';
      const mockEvent = {
        id: eventId,
        hostId: 'user-1', // different host
        visibility: Visibility.PRIVATE,
        tracks: [],
        invites: [{ userId: 'user-2' }], // user is invited
        host: { id: 'user-1', username: 'host' },
        currentTrack: null,
      };

      jest
        .spyOn(repository, 'findByIdWithDetails')
        .mockResolvedValue(mockEvent as any);
      jest.spyOn(repository, 'getCurrentTrackPayload').mockResolvedValue(null);

      const result = await service.findOne(eventId, userId);
      expect(result.id).toBe(eventId);
      expect(result.isHost).toBe(false);
      expect(result.isInvited).toBe(true);
      expect(result.currentTrack).toBeNull();
    });

    it('should throw ForbiddenException for private event without access', async () => {
      const eventId = 'event-1';
      const userId = 'user-2';
      const mockEvent = {
        id: eventId,
        hostId: 'user-1',
        visibility: Visibility.PRIVATE,
        invites: [],
      };

      jest
        .spyOn(repository, 'findByIdWithDetails')
        .mockResolvedValue(mockEvent as any);

      await expect(service.findOne(eventId, userId)).rejects.toThrow(
        ForbiddenException,
      );
    });
  });

  describe('update', () => {
    it('should throw ForbiddenException if not the host', async () => {
      const eventId = 'event-1';
      const userId = 'user-2';
      jest
        .spyOn(repository, 'findById')
        .mockResolvedValue({ hostId: 'user-1' } as any);

      await expect(
        service.update(eventId, userId, {} as any, mockMeta),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('inviteUser', () => {
    it('should throw ConflictException if inviting self', async () => {
      const eventId = 'event-1';
      const userId = 'user-1';
      jest
        .spyOn(repository, 'findById')
        .mockResolvedValue({ hostId: userId } as any);

      await expect(
        service.inviteUser(eventId, userId, userId, mockMeta),
      ).rejects.toThrow(ConflictException);
    });

    it('should emit a notification event when a user is invited', async () => {
      const eventId = 'event-1';
      const hostId = 'host-1';
      const invitedUserId = 'user-2';

      jest.spyOn(repository, 'findById').mockResolvedValue({
        id: eventId,
        hostId,
        name: 'Launch Party',
      } as any);
      jest.spyOn(repository, 'findUserById').mockResolvedValue({
        id: invitedUserId,
      } as any);
      jest.spyOn(repository, 'findInvite').mockResolvedValue(null);
      jest.spyOn(repository, 'createInvite').mockResolvedValue({
        id: 'invite-1',
      } as any);

      await service.inviteUser(eventId, hostId, invitedUserId, mockMeta);

      expect(eventEmitter.emit).toHaveBeenCalledWith(
        NOTIFICATION_TRIGGER_EVENT,
        expect.objectContaining({
          recipientId: invitedUserId,
          type: NotificationType.EVENT_INVITE,
          payload: {
            payloadType: NotificationPayloadType.EVENT,
            id: eventId,
            meta: { eventName: 'Launch Party' },
          },
          context: { eventName: 'Launch Party' },
        }),
      );
    });
  });

  describe('appendTrack', () => {
    it('should successfully append a track', async () => {
      const eventId = 'event-1';
      const userId = 'user-1';
      const providerTrackId = 'track-1';
      const mockTrack = { id: 't-1', providerTrackId };

      jest.spyOn(repository, 'findByIdWithInvites').mockResolvedValue({
        hostId: userId,
        visibility: Visibility.PUBLIC,
        invites: [],
      } as any);
      jest
        .spyOn(youtubeService, 'getTrackDetails')
        .mockResolvedValue({ providerTrackId, title: 'Title' } as any);
      jest
        .spyOn(repository, 'upsertTrackAndGet')
        .mockResolvedValue(mockTrack as any);
      jest.spyOn(repository, 'findEventTrack').mockResolvedValue(null);
      jest
        .spyOn(repository, 'createEventTrack')
        .mockResolvedValue({ id: 'et-1' } as any);

      const result = await service.appendTrack(
        eventId,
        userId,
        providerTrackId,
        mockMeta,
      );

      expect(result.id).toBe('et-1');
    });
  });

  describe('removeTrack', () => {
    it('should successfully remove a track', async () => {
      const eventId = 'event-1';
      const userId = 'user-1';
      const providerTrackId = 'track-1';
      const mockEventTrack = {
        id: 'et-1',
        addedById: userId,
        track: { providerTrackId },
      };

      jest
        .spyOn(repository, 'findById')
        .mockResolvedValue({ hostId: userId } as any);
      jest
        .spyOn(repository, 'findEventTrackByProviderId')
        .mockResolvedValue(mockEventTrack as any);

      const result = await service.removeTrack(
        eventId,
        providerTrackId,
        userId,
        mockMeta,
      );

      expect(result.providerTrackId).toBe(providerTrackId);
      expect(repository.deleteEventTrack).toHaveBeenCalledWith('et-1');
    });
  });

  describe('play', () => {
    it('should allow host to play', async () => {
      const eventId = 'event-1';
      const hostId = 'host-1';
      jest.spyOn(repository, 'findById').mockResolvedValue({
        id: eventId,
        hostId,
        status: 'LIVE',
      } as any);
      jest.spyOn(repository, 'updatePlaybackPlay').mockResolvedValue({
        currentTrackId: 't-1',
      } as any);

      const result = await service.play(eventId, hostId);

      expect(result.status).toBe('PLAYING');
    });

    it('should allow delegated user with matching deviceId to play', async () => {
      const eventId = 'event-1';
      const delegateeId = 'user-2';
      jest.spyOn(repository, 'findById').mockResolvedValue({
        id: eventId,
        hostId: 'host-1',
        status: 'LIVE',
      } as any);
      jest.spyOn(repository, 'findActiveDelegation').mockResolvedValue({
        deviceId: 'test-device-id',
      } as any);
      jest.spyOn(repository, 'updatePlaybackPlay').mockResolvedValue({
        currentTrackId: 't-1',
      } as any);

      const result = await service.play(eventId, delegateeId, 'test-device-id');

      expect(result.status).toBe('PLAYING');
    });

    it('should throw ForbiddenException for non-delegated user', async () => {
      const eventId = 'event-1';
      const userId = 'user-2';
      jest.spyOn(repository, 'findById').mockResolvedValue({
        id: eventId,
        hostId: 'host-1',
        status: 'LIVE',
      } as any);
      jest.spyOn(repository, 'findActiveDelegation').mockResolvedValue(null);

      await expect(
        service.play(eventId, userId, 'test-device-id'),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should throw ForbiddenException for device mismatch', async () => {
      const eventId = 'event-1';
      const delegateeId = 'user-2';
      jest.spyOn(repository, 'findById').mockResolvedValue({
        id: eventId,
        hostId: 'host-1',
        status: 'LIVE',
      } as any);
      jest.spyOn(repository, 'findActiveDelegation').mockResolvedValue({
        deviceId: 'other-device',
      } as any);

      await expect(
        service.play(eventId, delegateeId, 'test-device-id'),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('pause', () => {
    it('should allow host to pause', async () => {
      const eventId = 'event-1';
      const hostId = 'host-1';
      jest.spyOn(repository, 'findById').mockResolvedValue({
        id: eventId,
        hostId,
        status: 'LIVE',
        playbackStatus: 'PLAYING',
        currentTrackStartedAt: new Date(),
        pausedPlaybackPositionMs: 0,
      } as any);
      jest.spyOn(repository, 'updatePlaybackPause').mockResolvedValue({
        currentTrackId: 't-1',
      } as any);

      const result = await service.pause(eventId, hostId);

      expect(result.status).toBe('PAUSED');
    });

    it('should allow delegated user with matching deviceId to pause', async () => {
      const eventId = 'event-1';
      const delegateeId = 'user-2';
      jest.spyOn(repository, 'findById').mockResolvedValue({
        id: eventId,
        hostId: 'host-1',
        status: 'LIVE',
        playbackStatus: 'PLAYING',
        currentTrackStartedAt: new Date(),
        pausedPlaybackPositionMs: 0,
      } as any);
      jest.spyOn(repository, 'findActiveDelegation').mockResolvedValue({
        deviceId: 'test-device-id',
      } as any);
      jest.spyOn(repository, 'updatePlaybackPause').mockResolvedValue({
        currentTrackId: 't-1',
      } as any);

      const result = await service.pause(
        eventId,
        delegateeId,
        'test-device-id',
      );

      expect(result.status).toBe('PAUSED');
    });

    it('should throw ForbiddenException for non-delegated user on pause', async () => {
      const eventId = 'event-1';
      const userId = 'user-2';
      jest.spyOn(repository, 'findById').mockResolvedValue({
        id: eventId,
        hostId: 'host-1',
        status: 'LIVE',
        playbackStatus: 'PLAYING',
        currentTrackStartedAt: new Date(),
        pausedPlaybackPositionMs: 0,
      } as any);
      jest.spyOn(repository, 'findActiveDelegation').mockResolvedValue(null);

      await expect(
        service.pause(eventId, userId, 'test-device-id'),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('next', () => {
    it('should allow host to skip track', async () => {
      const eventId = 'event-1';
      const hostId = 'host-1';
      jest.spyOn(repository, 'findById').mockResolvedValue({
        id: eventId,
        hostId,
      } as any);
      jest.spyOn(repository, 'advanceQueue').mockResolvedValue({
        event: { currentTrackId: 't-2' },
        nextTrackId: 't-2',
      } as any);

      const result = await service.next(eventId, hostId, null);

      expect(result.currentTrackId).toBe('t-2');
    });

    it('should allow delegated user with matching deviceId to skip', async () => {
      const eventId = 'event-1';
      const delegateeId = 'user-2';
      jest.spyOn(repository, 'findById').mockResolvedValue({
        id: eventId,
        hostId: 'host-1',
      } as any);
      jest.spyOn(repository, 'findActiveDelegation').mockResolvedValue({
        deviceId: 'test-device-id',
      } as any);
      jest.spyOn(repository, 'advanceQueue').mockResolvedValue({
        event: { currentTrackId: 't-2' },
        nextTrackId: 't-2',
      } as any);

      const result = await service.next(
        eventId,
        delegateeId,
        null,
        'test-device-id',
      );

      expect(result.currentTrackId).toBe('t-2');
    });

    it('should throw ForbiddenException for non-delegated user on next', async () => {
      const eventId = 'event-1';
      const userId = 'user-2';
      jest.spyOn(repository, 'findById').mockResolvedValue({
        id: eventId,
        hostId: 'host-1',
      } as any);
      jest.spyOn(repository, 'findActiveDelegation').mockResolvedValue(null);

      await expect(
        service.next(eventId, userId, null, 'test-device-id'),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('findOne - isDelegated', () => {
    it('should return isDelegated true when user has active delegation', async () => {
      const eventId = 'event-1';
      const userId = 'user-2';
      const mockEvent = {
        id: eventId,
        hostId: 'host-1',
        visibility: Visibility.PUBLIC,
        tracks: [],
        invites: [],
        host: { id: 'host-1', username: 'host' },
        delegations: [{ delegateeId: userId, isActive: true }],
      };

      jest
        .spyOn(repository, 'findByIdWithDetails')
        .mockResolvedValue(mockEvent as any);

      const result = await service.findOne(eventId, userId);

      expect(result.isDelegated).toBe(true);
    });

    it('should return isDelegated false when user has no delegation', async () => {
      const eventId = 'event-1';
      const userId = 'user-2';

      const mockEventWithoutDelegation = {
        id: eventId,
        hostId: 'host-1',
        visibility: Visibility.PUBLIC,
        tracks: [],
        invites: [],
        host: { id: 'host-1', username: 'host' },
        delegations: [],
      };
      jest
        .spyOn(repository, 'findByIdWithDetails')
        .mockResolvedValue(mockEventWithoutDelegation as any);

      const result = await service.findOne(eventId, userId);
      expect(result.isDelegated).toBe(false);
    });
  });
});
