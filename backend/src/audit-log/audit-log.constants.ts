/**
 * Event name constant used by EventEmitter2 for audit log dispatch.
 */
export const AUDIT_LOG_EVENT = 'audit.log';

/**
 * Typed enum for all auditable user actions.
 * Kept at the application layer (not a Prisma enum) to avoid
 * a database migration every time a new action is added.
 */
export enum AuditAction {
  // Auth
  LOGIN = 'LOGIN',
  REGISTER = 'REGISTER',
  GOOGLE_AUTH = 'GOOGLE_AUTH',
  LINK_GOOGLE = 'LINK_GOOGLE',
  UNLINK_GOOGLE = 'UNLINK_GOOGLE',
  PASSWORD_RESET = 'PASSWORD_RESET',
  LOGOUT_ALL = 'LOGOUT_ALL',
  UPDATE_PROFILE = 'UPDATE_PROFILE',
  UPDATE_USERNAME = 'UPDATE_USERNAME',
  PASSWORD_CHANGE = 'PASSWORD_CHANGE',

  // Playlists
  PLAYLIST_CREATE = 'PLAYLIST_CREATE',
  PLAYLIST_UPDATE = 'PLAYLIST_UPDATE',
  PLAYLIST_DELETE = 'PLAYLIST_DELETE',
  PLAYLIST_TRACK_ADD = 'PLAYLIST_TRACK_ADD',
  PLAYLIST_TRACK_REMOVE = 'PLAYLIST_TRACK_REMOVE',
  PLAYLIST_TRACK_REORDER = 'PLAYLIST_TRACK_REORDER',
  COLLABORATOR_ADD = 'COLLABORATOR_ADD',

  // Live Events
  EVENT_CREATE = 'EVENT_CREATE',
  EVENT_UPDATE = 'EVENT_UPDATE',
  EVENT_DELETE = 'EVENT_DELETE',
  EVENT_TRACK_ADD = 'EVENT_TRACK_ADD',
  EVENT_TRACK_REMOVE = 'EVENT_TRACK_REMOVE',
  EVENT_INVITE = 'EVENT_INVITE',
  EVENT_START = 'EVENT_START',
  EVENT_END = 'EVENT_END',
  TRACK_SKIP = 'TRACK_SKIP',

  // Delegation
  DELEGATION_GRANT = 'DELEGATION_GRANT',
  DELEGATION_ACCEPTED = 'DELEGATION_ACCEPTED',
  DELEGATION_REVOKE = 'DELEGATION_REVOKE',
  DELEGATED_PLAY = 'DELEGATED_PLAY',
  DELEGATED_PAUSE = 'DELEGATED_PAUSE',
  DELEGATED_NEXT = 'DELEGATED_NEXT',

  // Votes
  VOTE_CAST = 'VOTE_CAST',

  // Notifications
  NOTIFICATION_LIST = 'NOTIFICATION_LIST',
  NOTIFICATION_READ = 'NOTIFICATION_READ',
}

/**
 * Standardized metadata for system-initiated or automated background job actions.
 */
export const SYSTEM_AUDIT_META = {
  platform: 'system',
  deviceModel: 'worker',
  deviceId: 'worker',
  appVersion: 'unknown',
  ipAddress: '127.0.0.1',
} as const;
