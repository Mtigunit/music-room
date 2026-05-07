import { Injectable, Logger } from '@nestjs/common';
import { OnEvent } from '@nestjs/event-emitter';
import { NotificationsService } from './notifications.service';
import { NOTIFICATION_TRIGGER_EVENT } from './notifications.constants';
import type { NotificationTriggerEvent } from './notifications.event';
import { NotificationType } from '@prisma/client';

@Injectable()
export class NotificationsListener {
  private readonly logger = new Logger(NotificationsListener.name);

  constructor(private readonly notificationsService: NotificationsService) {}

  @OnEvent(NOTIFICATION_TRIGGER_EVENT, { async: true })
  async handleTriggered(event: NotificationTriggerEvent): Promise<void> {
    try {
      const { title, message } = this.buildMessage(event);
      await this.notificationsService.createNotification(
        event.recipientId,
        event.type,
        event.payload,
        title,
        message,
      );
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : 'Unknown error';
      this.logger.error(
        `Failed to create notification [${event.type}]: ${message}`,
      );
    }
  }

  private buildMessage(event: NotificationTriggerEvent): {
    title: string;
    message: string | null;
  } {
    const actorName = event.context?.actorName;
    const eventName = event.context?.eventName;

    switch (event.type) {
      case NotificationType.FOLLOW:
        return {
          title: 'New follower',
          message: actorName
            ? `${actorName} started following you.`
            : 'You have a new follower.',
        };
      case NotificationType.EVENT_INVITE:
        return {
          title: 'Event invite',
          message: eventName
            ? `You were invited to ${eventName}.`
            : 'You were invited to an event.',
        };
      case NotificationType.EVENT_START:
        return {
          title: 'Event starting',
          message: eventName
            ? `${eventName} is starting now.`
            : 'An event you are following is starting now.',
        };
      default:
        return {
          title: 'Notification',
          message: null,
        };
    }
  }
}
