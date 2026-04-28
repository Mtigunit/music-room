import { AuditAction } from './audit-log.constants';

/**
 * Typed payload emitted via EventEmitter2 for every auditable action.
 * Services construct this and fire-and-forget via `eventEmitter.emit()`.
 */
export class AuditLogEvent {
  /** The user who performed the action. Null for unauthenticated actions. */
  userId: string | null;

  /** The action that was performed, from the AuditAction enum. */
  action: AuditAction;

  /** Client platform (e.g. 'ios', 'android', 'web'). */
  platform: string;

  /** Client device model (e.g. 'iPhone 15 Pro'). */
  deviceModel: string;

  /** Client app version (e.g. '1.2.0'). */
  appVersion: string;

  /** Action-specific context (trackId, playlistId, eventId, etc.). */
  metadata?: Record<string, unknown>;

  /** Client IP address for security auditing. */
  ipAddress?: string;
}

/**
 * Helper function to create an AuditLogEvent, automatically extracting
 * platform, device, version, and IP address from the ClientMetaDto.
 */
export function createAuditLogEvent(
  userId: string | null,
  action: AuditAction,
  meta: import('../common/dto/client-meta.dto').ClientMetaDto,
  metadata?: Record<string, unknown>,
): AuditLogEvent {
  return {
    userId,
    action,
    platform: meta.platform,
    deviceModel: meta.deviceModel,
    appVersion: meta.appVersion,
    ipAddress: meta.ipAddress,
    metadata,
  };
}
