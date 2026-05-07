import type { NotificationType } from '@prisma/client';
import type { NotificationPayload } from './dto/notification-payload.dto';

export interface NotificationTriggerEvent {
  recipientId: string;
  type: NotificationType;
  payload: NotificationPayload;
  context?: {
    actorName?: string;
    eventName?: string;
  };
}
