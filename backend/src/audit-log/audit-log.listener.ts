import { Injectable, Logger } from '@nestjs/common';
import { OnEvent } from '@nestjs/event-emitter';
import { AuditLogRepository } from './audit-log.repository';
import type { AuditLogEvent } from './audit-log.event';
import { AUDIT_LOG_EVENT } from './audit-log.constants';

/**
 * Listens for audit log events on the in-process event bus and
 * persists them asynchronously. Errors are caught and logged
 * never propagated so the original HTTP response is never affected.
 */
@Injectable()
export class AuditLogListener {
  private readonly logger = new Logger(AuditLogListener.name);

  constructor(private readonly auditLogRepository: AuditLogRepository) {}

  @OnEvent(AUDIT_LOG_EVENT, { async: true })
  async onAuditLog(event: AuditLogEvent): Promise<void> {
    try {
      await this.auditLogRepository.create(event);
    } catch (error: unknown) {
      // Swallow the error audit logging must never crash the caller.
      const message = error instanceof Error ? error.message : 'Unknown error';
      this.logger.error(
        `Failed to persist audit log [${event.action}]: ${message}`,
      );
    }
  }
}
