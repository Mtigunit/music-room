import { Injectable, NotFoundException } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import type { Notification, NotificationType } from '@prisma/client';
import { NotificationsRepository } from './notifications.repository';
import { NotificationsGateway } from './notifications.gateway';
import type { NotificationPayload } from './dto/notification-payload.dto';
import type { NotificationsQueryDto } from './dto/notification-query.dto';
import { NotificationResponseDto } from './dto/notification-response.dto';
import { AUDIT_LOG_EVENT, AuditAction } from '../audit-log/audit-log.constants';
import { createAuditLogEvent } from '../audit-log/audit-log.event';
import type { ClientMetaDto } from '../common/dto/client-meta.dto';

@Injectable()
export class NotificationsService {
  constructor(
    private readonly notificationsRepository: NotificationsRepository,
    private readonly notificationsGateway: NotificationsGateway,
    private readonly eventEmitter: EventEmitter2,
  ) {}

  async createNotification(
    userId: string,
    type: NotificationType,
    payload: NotificationPayload,
    title: string,
    message: string | null,
  ): Promise<NotificationResponseDto> {
    const notification = await this.notificationsRepository.createNotification({
      userId,
      type,
      payload,
      title,
      message,
    });

    const response = this.toResponseDto(notification);
    this.notificationsGateway.emitNewNotification(userId, response);

    return response;
  }

  async getNotifications(
    userId: string,
    query: NotificationsQueryDto,
    meta: ClientMetaDto,
  ): Promise<{
    data: NotificationResponseDto[];
    meta: { total: number; page: number; limit: number };
  }> {
    const result = await this.notificationsRepository.findForUser(
      userId,
      query,
    );

    this.eventEmitter.emit(
      AUDIT_LOG_EVENT,
      createAuditLogEvent(userId, AuditAction.NOTIFICATION_LIST, meta),
    );

    return {
      data: result.data.map((notification) => this.toResponseDto(notification)),
      meta: result.meta,
    };
  }

  async markAsRead(
    userId: string,
    notificationId: string,
    meta: ClientMetaDto,
  ): Promise<NotificationResponseDto> {
    const notification = await this.notificationsRepository.markAsRead(
      userId,
      notificationId,
    );

    if (!notification) {
      throw new NotFoundException('Notification not found');
    }

    this.eventEmitter.emit(
      AUDIT_LOG_EVENT,
      createAuditLogEvent(userId, AuditAction.NOTIFICATION_READ, meta, {
        notificationId,
      }),
    );

    return this.toResponseDto(notification);
  }

  private toResponseDto(notification: Notification): NotificationResponseDto {
    return {
      id: notification.id,
      type: notification.type,
      title: notification.title,
      message: notification.message,
      payload: notification.payload as unknown as NotificationPayload,
      isRead: notification.readAt !== null,
      createdAt: notification.createdAt.toISOString(),
      readAt: notification.readAt ? notification.readAt.toISOString() : null,
    };
  }
}
