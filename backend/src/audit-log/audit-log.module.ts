import { Global, Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { AuditLogRepository } from './audit-log.repository';
import { AuditLogListener } from './audit-log.listener';

/**
 * Global module — the AuditLogListener auto-registers on the event bus.
 * Any module can emit audit events via EventEmitter2 without importing
 * this module explicitly.
 */
@Global()
@Module({
  imports: [PrismaModule],
  providers: [AuditLogRepository, AuditLogListener],
})
export class AuditLogModule {}
