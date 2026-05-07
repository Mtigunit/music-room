import { Injectable } from '@nestjs/common';
import { Prisma, Notification, NotificationType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import type { NotificationPayload } from './dto/notification-payload.dto';
import type { NotificationsQueryDto } from './dto/notification-query.dto';

@Injectable()
export class NotificationsRepository {
  constructor(private readonly prisma: PrismaService) {}

  async createNotification(data: {
    userId: string;
    type: NotificationType;
    title: string;
    message: string | null;
    payload: NotificationPayload;
  }): Promise<Notification> {
    return this.prisma.notification.create({
      data: {
        userId: data.userId,
        type: data.type,
        title: data.title,
        message: data.message,
        payload: data.payload as unknown as Prisma.InputJsonValue,
      },
    });
  }

  async findForUser(
    userId: string,
    query: NotificationsQueryDto,
  ): Promise<{
    data: Notification[];
    meta: { total: number; page: number; limit: number };
  }> {
    const { page = 1, limit = 20 } = query;
    const skip = (page - 1) * limit;

    const where: Prisma.NotificationWhereInput = {
      userId,
    };

    const [data, total] = await Promise.all([
      this.prisma.notification.findMany({
        where,
        take: limit,
        skip,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.notification.count({ where }),
    ]);

    return { data, meta: { total, page, limit } };
  }

  async markAsRead(
    userId: string,
    notificationId: string,
  ): Promise<Notification | null> {
    await this.prisma.notification.updateMany({
      where: { id: notificationId, userId, readAt: null },
      data: { readAt: new Date() },
    });

    return this.prisma.notification.findFirst({
      where: { id: notificationId, userId },
    });
  }
}
