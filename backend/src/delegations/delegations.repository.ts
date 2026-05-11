import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class DelegationsRepository {
  constructor(private readonly prisma: PrismaService) {}

  async findActive(eventId: string, delegateeId: string) {
    return this.prisma.controlDelegation.findFirst({
      where: {
        eventId,
        delegateeId,
        isActive: true,
      },
    });
  }

  async findByEventId(eventId: string) {
    return this.prisma.controlDelegation.findMany({
      where: { eventId, isActive: true },
      include: {
        delegatee: {
          select: { id: true, username: true, avatarUrl: true },
        },
      },
    });
  }

  async createPending(eventId: string, delegateeId: string) {
    return this.prisma.controlDelegation.upsert({
      where: { eventId_delegateeId: { eventId, delegateeId } },
      create: {
        eventId,
        delegateeId,
        deviceId: null,
        isActive: false,
      },
      update: {
        deviceId: null,
        isActive: false,
      },
    });
  }

  async activateById(delegationId: string, deviceId: string) {
    return this.prisma.controlDelegation.updateMany({
      where: { id: delegationId, isActive: false },
      data: { deviceId, isActive: true },
    });
  }

  async findPendingById(delegateeId: string, eventId: string) {
    return this.prisma.controlDelegation.findFirst({
      where: {
        eventId,
        delegateeId,
        isActive: false,
      },
    });
  }

  async deletePending(eventId: string, delegateeId: string) {
    return this.prisma.controlDelegation.deleteMany({
      where: {
        eventId,
        delegateeId,
        isActive: false,
      },
    });
  }

  async revoke(eventId: string, delegateeId: string) {
    return this.prisma.controlDelegation.updateMany({
      where: {
        eventId,
        delegateeId,
        isActive: true,
      },
      data: { isActive: false },
    });
  }

  async findEventById(eventId: string) {
    return this.prisma.event.findUnique({ where: { id: eventId } });
  }
}
