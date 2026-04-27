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
  PASSWORD_RESET = 'PASSWORD_RESET',

  // Playlists
  PLAYLIST_CREATE = 'PLAYLIST_CREATE',
  PLAYLIST_TRACK_ADD = 'PLAYLIST_TRACK_ADD',
  PLAYLIST_TRACK_REMOVE = 'PLAYLIST_TRACK_REMOVE',
  PLAYLIST_TRACK_REORDER = 'PLAYLIST_TRACK_REORDER',

  // Live Events
  EVENT_CREATE = 'EVENT_CREATE',
  EVENT_TRACK_ADD = 'EVENT_TRACK_ADD',
  EVENT_TRACK_REMOVE = 'EVENT_TRACK_REMOVE',
  TRACK_SKIP = 'TRACK_SKIP',

  // Votes
  VOTE_CAST = 'VOTE_CAST',
}
