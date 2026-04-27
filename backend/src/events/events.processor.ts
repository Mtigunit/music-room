import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { Logger } from '@nestjs/common';
import { EventsGateway } from './events.gateway';
import {
  BULL_QUEUES,
  BULL_JOBS,
  REDIS_KEYS,
  WS_EVENTS,
} from './events.constants';
import { RedisService } from '../redis/redis.service';
import { PrismaService } from '../prisma/prisma.service';
import { EventStatus } from '@prisma/client';

export interface EventTimeoutJobData {
  eventId: string;
  userId: string;
}

@Processor(BULL_QUEUES.EVENT_TIMEOUTS)
export class EventsProcessor extends WorkerHost {
  private readonly logger = new Logger(EventsProcessor.name);

  constructor(
    private readonly eventsGateway: EventsGateway,
    private readonly redisService: RedisService,
    private readonly prisma: PrismaService,
  ) {
    super();
  }

  async process(job: Job<EventTimeoutJobData, void, string>): Promise<void> {
    const { eventId, userId } = job.data;

    switch (job.name) {
      case BULL_JOBS.HOST_SOFT_TIMEOUT:
        return this.handleSoftTimeout(eventId, userId);
      case BULL_JOBS.HOST_HARD_TIMEOUT:
        return this.handleHardTimeout(eventId, userId);
      default:
        this.logger.warn(`Unknown job name: ${job.name}`);
    }
  }

  private async handleSoftTimeout(eventId: string, userId: string) {
    const flagKey = REDIS_KEYS.HOST_DISCONNECT(eventId);
    const client = this.redisService.getClient();
    const currentFlag = await client.get(flagKey);

    if (currentFlag !== userId) {
      this.logger.debug(
        `Soft timeout for ${eventId} ignored, host back or wrong flag`,
      );
      return;
    }

    // Host still gone after 5s
    const roomName = `event_${eventId}`;
    this.eventsGateway.server
      .to(roomName)
      .emit(WS_EVENTS.HOST_SOFT_DISCONNECT, {
        gracePeriodSeconds:
          (BULL_JOBS.HARD_TIMEOUT - BULL_JOBS.SOFT_TIMEOUT) / 1000,
      });
    this.logger.log(`Broadcasted soft disconnect warning for event ${eventId}`);
  }

  private async handleHardTimeout(eventId: string, userId: string) {
    const flagKey = REDIS_KEYS.HOST_DISCONNECT(eventId);
    const client = this.redisService.getClient();
    const currentFlag = await client.get(flagKey);

    if (currentFlag !== userId) {
      this.logger.debug(
        `Hard timeout for ${eventId} ignored, host back or wrong flag`,
      );
      return;
    }

    // Host never came back
    await this.prisma.event.update({
      where: { id: eventId },
      data: { status: EventStatus.ENDED },
    });

    const roomName = `event_${eventId}`;
    this.eventsGateway.server.to(roomName).emit(WS_EVENTS.ENDED, {
      reason: 'host_unreachable',
    });
    this.eventsGateway.server.in(roomName).socketsLeave(roomName);

    await client.del(
      REDIS_KEYS.HOST_DISCONNECT(eventId),
      REDIS_KEYS.EVENT_HOST(eventId),
      REDIS_KEYS.HOST_SOCKET(eventId),
    );

    this.logger.log(`Ended event ${eventId} due to host hard timeout`);
  }
}
