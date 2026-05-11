import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  ConflictException,
} from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { DelegationsRepository } from './delegations.repository';
import { AUDIT_LOG_EVENT, AuditAction } from '../audit-log/audit-log.constants';
import { createAuditLogEvent } from '../audit-log/audit-log.event';
import type { ClientMetaDto } from '../common/dto/client-meta.dto';
import { INTERNAL_EVENTS } from '../events/events.constants';
import { EventStatus } from '@prisma/client';
import { UserRepository } from '../users/user.repository';

@Injectable()
export class DelegationsService {
  constructor(
    private readonly delegationsRepository: DelegationsRepository,
    private readonly userRepository: UserRepository,
    private readonly eventEmitter: EventEmitter2,
  ) {}

  async grant(
    eventId: string,
    hostId: string,
    delegateeId: string,
    meta: ClientMetaDto,
  ) {
    const event = await this.delegationsRepository.findEventById(eventId);
    if (!event || event.status === EventStatus.ENDED)
      throw new NotFoundException('Event not found or ended');
    if (event.hostId !== hostId)
      throw new ForbiddenException('Only the host can grant delegation');
    if (hostId === delegateeId)
      throw new ForbiddenException('Cannot delegate to yourself');

    const user = await this.userRepository.findById(delegateeId);
    if (!user) throw new NotFoundException('User not found');

    const activeDelegation = await this.delegationsRepository.findActive(
      eventId,
      delegateeId,
    );
    if (activeDelegation)
      throw new ConflictException(
        'Active delegation already exists for this pair',
      );

    const pending = await this.delegationsRepository.createPending(
      eventId,
      delegateeId,
    );

    this.eventEmitter.emit(INTERNAL_EVENTS.DELEGATION_INVITE_SENT, {
      eventId,
      delegateeId,
      delegationId: pending.id,
      hostname: user.username,
      eventName: event.name,
    });

    this.eventEmitter.emit(
      AUDIT_LOG_EVENT,
      createAuditLogEvent(hostId, AuditAction.DELEGATION_GRANT, meta, {
        eventId,
        delegationId: pending.id,
      }),
    );

    return {
      message: 'Delegation invite sent successfully',
      delegationId: pending.id,
    };
  }

  async revoke(
    eventId: string,
    hostId: string,
    delegateeId: string,
    meta: ClientMetaDto,
  ) {
    const event = await this.delegationsRepository.findEventById(eventId);
    if (!event || event.status === EventStatus.ENDED)
      throw new NotFoundException('Event not found or ended');
    if (event.hostId !== hostId)
      throw new ForbiddenException('Only the host can revoke delegation');

    await this.delegationsRepository.revoke(eventId, delegateeId);

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
    const event = await this.delegationsRepository.findEventById(eventId);
    if (!event || event.status === EventStatus.ENDED)
      throw new NotFoundException('Event not found or ended');
    if (event.hostId !== hostId)
      throw new ForbiddenException('Only the host can list delegations');

    return this.delegationsRepository.findByEventId(eventId);
  }
}
