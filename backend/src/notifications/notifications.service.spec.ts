import { Test, TestingModule } from '@nestjs/testing';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { NotificationsService } from './notifications.service';
import { NotificationsRepository } from './notifications.repository';
import { NotificationsGateway } from './notifications.gateway';
import { NotificationType } from '@prisma/client';
import type { NotificationPayload } from './dto/notification-payload.dto';

describe('NotificationsService', () => {
  let service: NotificationsService;
  let repository: jest.Mocked<NotificationsRepository>;
  let gateway: jest.Mocked<NotificationsGateway>;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        NotificationsService,
        {
          provide: NotificationsRepository,
          useValue: {
            createNotification: jest.fn(),
            findForUser: jest.fn(),
            markAsRead: jest.fn(),
          },
        },
        {
          provide: NotificationsGateway,
          useValue: {
            sendPush: jest.fn(),
          },
        },
        {
          provide: EventEmitter2,
          useValue: { emit: jest.fn() },
        },
      ],
    }).compile();

    service = module.get(NotificationsService);
    repository = module.get(NotificationsRepository);
    gateway = module.get(NotificationsGateway);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('createNotification', () => {
    it('creates a notification and sends a push event', async () => {
      const userId = 'user-1';
      const now = new Date('2026-05-06T12:00:00.000Z');
      const payload: NotificationPayload = {
        payloadType: 'EVENT',
        id: 'event-1',
      } as NotificationPayload;

      repository.createNotification.mockResolvedValue({
        id: 'notif-1',
        userId,
        type: NotificationType.EVENT_INVITE,
        title: 'Event invite',
        message: 'You were invited to an event.',
        payload: payload as unknown,
        readAt: null,
        createdAt: now,
      } as any);

      const result = await service.createNotification(
        userId,
        NotificationType.EVENT_INVITE,
        payload,
        'Event invite',
        'You were invited to an event.',
      );

      expect(repository.createNotification).toHaveBeenCalledWith({
        userId,
        type: NotificationType.EVENT_INVITE,
        payload,
        title: 'Event invite',
        message: 'You were invited to an event.',
      });

      expect(gateway.sendPush).toHaveBeenCalledWith(userId, {
        id: 'notif-1',
        type: NotificationType.EVENT_INVITE,
        title: 'Event invite',
        message: 'You were invited to an event.',
        payload,
        isRead: false,
        createdAt: now.toISOString(),
        readAt: null,
      });

      expect(result).toEqual({
        id: 'notif-1',
        type: NotificationType.EVENT_INVITE,
        title: 'Event invite',
        message: 'You were invited to an event.',
        payload,
        isRead: false,
        createdAt: now.toISOString(),
        readAt: null,
      });
    });
  });
});
