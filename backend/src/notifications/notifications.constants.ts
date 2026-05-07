export const NOTIFICATION_TRIGGER_EVENT = 'notification.triggered';
export const NOTIFICATION_NEW_EVENT = 'notification:new';
export const NOTIFICATION_ROOM_PREFIX = 'user_';

export const buildNotificationRoom = (userId: string): string =>
  `${NOTIFICATION_ROOM_PREFIX}${userId}`;
