import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { PrismaService } from '../prisma/prisma.service';
import { DelegationsRepository } from './delegations.repository';
import { AUDIT_LOG_EVENT, AuditAction } from '../audit-log/audit-log.constants';
import { createAuditLogEvent } from '../audit-log/audit-log.event';
import type { ClientMetaDto } from '../common/dto/client-meta.dto';

const HARDCODED_DEVICE_ID = 'test-device-id';

@Injectable()
export class DelegationsService {
  constructor(
    private readonly delegationsRepository: DelegationsRepository,
    private readonly prisma: PrismaService,
    private readonly eventEmitter: EventEmitter2,
  ) {}

  async grant(
    eventId: string,
    hostId: string,
    delegateeId: string,
    meta: ClientMetaDto,
  ) {
    const event = await this.prisma.event.findUnique({
      where: { id: eventId },
    });
    if (!event) throw new NotFoundException('Event not found');
    if (event.hostId !== hostId) {
      throw new ForbiddenException('Only the host can grant delegation');
    }
    if (hostId === delegateeId) {
      throw new ForbiddenException('Cannot delegate to yourself');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: delegateeId },
    });
    if (!user) throw new NotFoundException('User not found');

    const result = await this.delegationsRepository.createOrUpdate(
      eventId,
      delegateeId,
      HARDCODED_DEVICE_ID,
    );

    this.eventEmitter.emit(
      AUDIT_LOG_EVENT,
      createAuditLogEvent(hostId, AuditAction.DELEGATION_GRANT, meta, {
        eventId,
        delegateeId,
      }),
    );

    return result;
  }

  async revoke(
    eventId: string,
    hostId: string,
    delegateeId: string,
    meta: ClientMetaDto,
  ) {
    const event = await this.prisma.event.findUnique({
      where: { id: eventId },
    });
    if (!event) throw new NotFoundException('Event not found');
    if (event.hostId !== hostId) {
      throw new ForbiddenException('Only the host can revoke delegation');
    }

    const result = await this.delegationsRepository.revoke(
      eventId,
      delegateeId,
    );
    if (result.count === 0) {
      throw new NotFoundException('Delegation not found');
    }

    this.eventEmitter.emit(
      AUDIT_LOG_EVENT,
      createAuditLogEvent(hostId, AuditAction.DELEGATION_REVOKE, meta, {
        eventId,
        delegateeId,
      }),
    );

    return { message: 'Delegation revoked successfully' };
  }

  async list(eventId: string, hostId: string) {
    const event = await this.prisma.event.findUnique({
      where: { id: eventId },
    });
    if (!event) throw new NotFoundException('Event not found');
    if (event.hostId !== hostId) {
      throw new ForbiddenException('Only the host can list delegations');
    }

    return this.delegationsRepository.findByEventId(eventId);
  }
}
