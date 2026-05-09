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

  async createOrUpdate(eventId: string, delegateeId: string, deviceId: string) {
    return this.prisma.controlDelegation.upsert({
      where: {
        eventId_delegateeId_deviceId: {
          eventId,
          delegateeId,
          deviceId,
        },
      },
      create: {
        eventId,
        delegateeId,
        deviceId,
        isActive: true,
      },
      update: {
        isActive: true,
      },
    });
  }

  async revoke(eventId: string, delegateeId: string) {
    return this.prisma.controlDelegation.updateMany({
      where: {
        eventId,
        delegateeId,
      },
      data: { isActive: false },
    });
  }
}
