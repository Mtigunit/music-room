import { Test, TestingModule } from '@nestjs/testing';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { NotificationsService } from './notifications.service';
import { NotificationsRepository } from './notifications.repository';
import { NotificationsGateway } from './notifications.gateway';
import { NotificationType } from '@prisma/client';
import type { NotificationPayload } from './dto/notification-payload.dto';
import { NotFoundException } from '@nestjs/common';
import { AUDIT_LOG_EVENT, AuditAction } from '../audit-log/audit-log.constants';
import type { ClientMetaDto } from '../common/dto/client-meta.dto';
import type { NotificationsQueryDto } from './dto/notification-query.dto';
describe('NotificationsService', () => {
  let service: NotificationsService;
  let repository: jest.Mocked<NotificationsRepository>;
  let gateway: jest.Mocked<NotificationsGateway>;
  let eventEmitter: jest.Mocked<EventEmitter2>;

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
    eventEmitter = module.get(EventEmitter2) as jest.Mocked<EventEmitter2>;
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

  describe('getNotifications', () => {
    it('returns paginated mapped notifications and emits audit log', async () => {
      const userId = 'user-1';
      const now = new Date('2026-05-06T12:00:00.000Z');
      const payload: NotificationPayload = {
        payloadType: 'USER',
        id: 'user-2',
      } as NotificationPayload;

      const mockNotification = {
        id: 'notif-1',
        userId,
        type: NotificationType.FOLLOW,
        title: 'New follower',
        message: 'You have a new follower',
        payload: payload as unknown,
        readAt: null,
        createdAt: now,
      };

      repository.findForUser.mockResolvedValue({
        data: [mockNotification as any],
        meta: { total: 1, page: 1, limit: 10 },
      });

      const query: NotificationsQueryDto = { page: 1, limit: 10 };
      const meta: ClientMetaDto = {
        platform: 'ios',
        deviceModel: 'iPhone',
        appVersion: '1.0',
      };

      const result = await service.getNotifications(userId, query, meta);

      expect(repository.findForUser).toHaveBeenCalledWith(userId, query);
      expect(eventEmitter.emit).toHaveBeenCalledWith(
        AUDIT_LOG_EVENT,
        expect.objectContaining({
          userId,
          action: AuditAction.NOTIFICATION_LIST,
          platform: 'ios',
        }),
      );

      expect(result).toEqual({
        data: [
          {
            id: 'notif-1',
            type: NotificationType.FOLLOW,
            title: 'New follower',
            message: 'You have a new follower',
            payload,
            isRead: false,
            createdAt: now.toISOString(),
            readAt: null,
          },
        ],
        meta: { total: 1, page: 1, limit: 10 },
      });
    });
  });

  describe('markAsRead', () => {
    it('marks as read, maps response, and emits audit log', async () => {
      const userId = 'user-1';
      const notificationId = 'notif-1';
      const now = new Date('2026-05-06T12:00:00.000Z');
      const payload: NotificationPayload = {
        payloadType: 'USER',
        id: 'user-2',
      } as NotificationPayload;

      repository.markAsRead.mockResolvedValue({
        id: notificationId,
        userId,
        type: NotificationType.FOLLOW,
        title: 'New follower',
        message: 'You have a new follower',
        payload: payload as unknown,
        readAt: now,
        createdAt: now,
      } as any);

      const meta: ClientMetaDto = {
        platform: 'ios',
        deviceModel: 'iPhone',
        appVersion: '1.0',
      };

      const result = await service.markAsRead(userId, notificationId, meta);

      expect(repository.markAsRead).toHaveBeenCalledWith(userId, notificationId);
      expect(eventEmitter.emit).toHaveBeenCalledWith(
        AUDIT_LOG_EVENT,
        expect.objectContaining({
          userId,
          action: AuditAction.NOTIFICATION_READ,
          platform: 'ios',
          metadata: { notificationId },
        }),
      );

      expect(result).toEqual({
        id: notificationId,
        type: NotificationType.FOLLOW,
        title: 'New follower',
        message: 'You have a new follower',
        payload,
        isRead: true,
        createdAt: now.toISOString(),
        readAt: now.toISOString(),
      });
    });

    it('throws NotFoundException if notification does not exist', async () => {
      const userId = 'user-1';
      const notificationId = 'notif-invalid';
      repository.markAsRead.mockResolvedValue(null);

      const meta: ClientMetaDto = {
        platform: 'ios',
        deviceModel: 'iPhone',
        appVersion: '1.0',
      };

      await expect(
        service.markAsRead(userId, notificationId, meta),
      ).rejects.toThrow(NotFoundException);

      expect(repository.markAsRead).toHaveBeenCalledWith(userId, notificationId);
      expect(eventEmitter.emit).not.toHaveBeenCalled();
    });
  });
});
