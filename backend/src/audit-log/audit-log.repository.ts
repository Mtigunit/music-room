import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma } from '@prisma/client';
import { AuditLogEvent } from './audit-log.event';

@Injectable()
export class AuditLogRepository {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Persist a single audit log entry.
   */
  async create(event: AuditLogEvent): Promise<void> {
    await this.prisma.auditLog.create({
      data: {
        userId: event.userId,
        action: event.action,
        platform: event.platform,
        deviceModel: event.deviceModel,
        appVersion: event.appVersion,
        metadata: (event.metadata as Prisma.InputJsonObject) ?? Prisma.JsonNull,
        ipAddress: event.ipAddress ?? null,
      },
    });
  }
}
