import {
  ConnectedSocket,
  MessageBody,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
  WsException,
  OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Logger, UseGuards } from '@nestjs/common';
import { Server, Socket } from 'socket.io';
import { WsAuthGuard } from '../websockets/guards/ws-auth.guard';
import { PrismaService } from '../prisma/prisma.service';
import { EventStatus, Visibility } from '@prisma/client';
import { WsUser } from '../websockets/decorators/ws-user.decorator';
import type { SocketUser } from '../websockets/socket-auth.service';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import {
  WS_EVENTS,
  REDIS_KEYS,
  BULL_QUEUES,
  BULL_JOBS,
} from './events.constants';
import { RedisService } from '../redis/redis.service';

@WebSocketGateway({ path: '/ws', cors: true })
@UseGuards(WsAuthGuard)
export class EventsGateway implements OnGatewayDisconnect {
  @WebSocketServer()
  server!: Server;

  private readonly logger = new Logger(EventsGateway.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly redisService: RedisService,
    @InjectQueue(BULL_QUEUES.EVENT_TIMEOUTS)
    private readonly eventTimeoutsQueue: Queue,
  ) {}

  private getRoomCount(roomName: string): number {
    const room = this.server.sockets.adapter.rooms.get(roomName);
    return room ? room.size : 0;
  }

  private broadcastRoomCount(roomName: string) {
    const count = this.getRoomCount(roomName);
    this.server
      .to(roomName)
      .emit(WS_EVENTS.EVENT_COUNT, { room: roomName, count });
  }

  async handleDisconnect(client: Socket) {
    const data = client.data as { user?: SocketUser };
    const user = data?.user;
    if (!user) return;

    const liveEvent = await this.prisma.event.findFirst({
      where: { hostId: user.id, status: EventStatus.LIVE },
    });
    if (liveEvent) {
      const redisClient = this.redisService.getClient();
      const hostSocketKey = REDIS_KEYS.HOST_SOCKET(liveEvent.id);
      const currentHostSocketId = await redisClient.get(hostSocketKey);

      if (currentHostSocketId === client.id) {
        await this.startHostGracePeriod(liveEvent.id, user.id);
      }
    }
  }

  private async startHostGracePeriod(eventId: string, userId: string) {
    const redisClient = this.redisService.getClient();
    this.logger.log(
      `Host ${userId} disconnected or left event ${eventId}, starting grace period.`,
    );
    await redisClient.setex(REDIS_KEYS.HOST_DISCONNECT(eventId), 95, userId);

    await this.eventTimeoutsQueue.add(
      BULL_JOBS.HOST_SOFT_TIMEOUT,
      { eventId, userId },
      {
        delay: BULL_JOBS.SOFT_TIMEOUT,
        jobId: `soft-${eventId}`,
        removeOnComplete: true,
        removeOnFail: true,
      },
    );

    await this.eventTimeoutsQueue.add(
      BULL_JOBS.HOST_HARD_TIMEOUT,
      { eventId, userId },
      {
        delay: BULL_JOBS.HARD_TIMEOUT,
        jobId: `hard-${eventId}`,
        removeOnComplete: true,
        removeOnFail: true,
      },
    );
  }

  @SubscribeMessage(WS_EVENTS.JOIN)
  async handleEventJoin(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { eventId: string },
    @WsUser() user: SocketUser,
  ) {
    if (!payload?.eventId) {
      throw new WsException('eventId is required');
    }

    const userId = user.id;
    const eventId = payload.eventId;

    const event = await this.prisma.event.findUnique({
      where: { id: eventId },
      include: { invites: true },
    });

    if (!event) throw new WsException('Event not found');
    if (event.hostId === userId)
      throw new WsException(
        'Forbidden: Host must use host_join to join an event',
      );
    if (event.status === EventStatus.ENDED)
      throw new WsException('Event has already ended');

    if (event.visibility === Visibility.PRIVATE) {
      const isInvited = event.invites.some((i) => i.userId === userId);
      if (!isInvited) {
        throw new WsException('Forbidden: Cannot join private event room');
      }
    }

    const roomName = `event_${eventId}`;
    await client.join(roomName);

    this.logger.log(
      `Client ${client.id} (User: ${userId}) joined room ${roomName}`,
    );
    this.broadcastRoomCount(roomName);

    client.emit(WS_EVENTS.STATUS, {
      eventId,
      status: event.status,
      startDate: event.startDate,
    });

    this.server.to(roomName).emit(WS_EVENTS.USER_JOINED, { userId });

    return { event: 'joined', eventId, status: event.status };
  }

  @SubscribeMessage(WS_EVENTS.HOST_JOIN)
  async handleHostJoin(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { eventId: string },
    @WsUser() user: SocketUser,
  ) {
    if (!payload?.eventId) throw new WsException('eventId is required');

    const eventId = payload.eventId;
    const userId = user.id;

    const event = await this.prisma.event.findUnique({
      where: { id: eventId },
    });

    if (!event) throw new WsException('Event not found');
    if (event.hostId !== userId)
      throw new WsException('Forbidden: Only host can use host_join');
    if (event.status === EventStatus.ENDED)
      throw new WsException('Event has already ended');

    const roomName = `event_${eventId}`;
    await client.join(roomName);

    this.logger.log(
      `Host ${client.id} (User: ${userId}) joined room ${roomName}`,
    );
    this.broadcastRoomCount(roomName);

    await this.handleHostRejoined(eventId, userId, client.id);

    client.emit(WS_EVENTS.STATUS, {
      eventId,
      status: event.status,
      startDate: event.startDate,
    });

    return { event: 'host_joined', eventId, status: event.status };
  }

  private async handleHostRejoined(
    eventId: string,
    userId: string,
    socketId: string,
  ) {
    const redisClient = this.redisService.getClient();
    const disconnectFlag = await redisClient.get(
      REDIS_KEYS.HOST_DISCONNECT(eventId),
    );

    await redisClient.set(REDIS_KEYS.HOST_SOCKET(eventId), socketId);

    if (disconnectFlag === userId) {
      this.logger.log(
        `Host ${userId} rejoined event ${eventId} in time, canceling timeouts.`,
      );
      await redisClient.del(REDIS_KEYS.HOST_DISCONNECT(eventId));

      const softJob = await this.eventTimeoutsQueue.getJob(`soft-${eventId}`);
      if (softJob) await softJob.remove();

      const hardJob = await this.eventTimeoutsQueue.getJob(`hard-${eventId}`);
      if (hardJob) await hardJob.remove();

      const roomName = `event_${eventId}`;
      this.server
        .to(roomName)
        .emit(WS_EVENTS.HOST_RECONNECTED, { hostId: userId });
    }
  }

  @SubscribeMessage(WS_EVENTS.LEAVE)
  async handleEventLeave(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { eventId: string },
    @WsUser() user: SocketUser,
  ) {
    if (!payload?.eventId) throw new WsException('eventId is required');

    const eventId = payload.eventId;
    const userId = user.id;

    const event = await this.prisma.event.findUnique({
      where: { id: eventId },
    });

    if (!event) throw new WsException('Event not found');
    if (event.hostId === userId)
      throw new WsException(
        'Forbidden: Host must use host_leave to leave an event',
      );

    const roomName = `event_${eventId}`;
    await client.leave(roomName);
    this.logger.log(`Client ${client.id} left room ${roomName}`);
    this.broadcastRoomCount(roomName);

    return { event: 'left', eventId };
  }

  @SubscribeMessage(WS_EVENTS.HOST_LEAVE)
  async handleHostLeave(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { eventId: string },
    @WsUser() user: SocketUser,
  ) {
    if (!payload?.eventId) throw new WsException('eventId is required');

    const eventId = payload.eventId;
    const userId = user.id;

    const event = await this.prisma.event.findUnique({
      where: { id: eventId },
    });

    if (!event) throw new WsException('Event not found');
    if (event.hostId !== userId)
      throw new WsException('Forbidden: Only host can use host_leave');

    const roomName = `event_${eventId}`;
    await client.leave(roomName);
    this.logger.log(`Host ${client.id} explicitly left room ${roomName}`);
    this.broadcastRoomCount(roomName);

    if (event.status === EventStatus.LIVE) {
      await this.startHostGracePeriod(eventId, userId);
    }

    return { event: 'host_left', eventId };
  }

  @SubscribeMessage(WS_EVENTS.START)
  async handleEventStart(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { eventId: string },
    @WsUser() user: SocketUser,
  ) {
    if (!payload?.eventId) throw new WsException('eventId is required');

    const eventId = payload.eventId;
    const userId = user.id;

    const event = await this.prisma.event.findUnique({
      where: { id: eventId },
    });
    if (!event) throw new WsException('Event not found');
    if (event.hostId !== userId)
      throw new WsException('Forbidden: Only host can start the event');
    if (event.status === EventStatus.LIVE)
      throw new WsException('Forbidden: Event is already live');

    const updatedEvent = await this.prisma.event.update({
      where: { id: eventId },
      data: { status: EventStatus.LIVE, startDate: new Date() },
    });

    const redisClient = this.redisService.getClient();
    await redisClient.set(REDIS_KEYS.EVENT_HOST(eventId), userId);
    await redisClient.set(REDIS_KEYS.HOST_SOCKET(eventId), client.id);

    const roomName = `event_${eventId}`;
    await client.join(roomName);

    this.server.to(roomName).emit(WS_EVENTS.STARTED, {
      eventId,
      status: EventStatus.LIVE,
      startDate: updatedEvent.startDate,
      hostId: userId,
    });

    return { event: 'started', eventId, status: EventStatus.LIVE };
  }

  @SubscribeMessage(WS_EVENTS.END)
  async handleEventEnd(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { eventId: string },
    @WsUser() user: SocketUser,
  ) {
    if (!payload?.eventId) throw new WsException('eventId is required');

    const eventId = payload.eventId;
    const userId = user.id;

    const event = await this.prisma.event.findUnique({
      where: { id: eventId },
    });
    if (!event) throw new WsException('Event not found');
    if (event.hostId !== userId)
      throw new WsException('Forbidden: Only host can end the event');
    if (event.status !== EventStatus.LIVE)
      throw new WsException('Forbidden: Event is not live');

    await this.prisma.event.update({
      where: { id: eventId },
      data: { status: EventStatus.ENDED },
    });

    const redisClient = this.redisService.getClient();
    await redisClient.del(
      ...[
        REDIS_KEYS.EVENT_HOST(eventId),
        REDIS_KEYS.HOST_SOCKET(eventId),
        REDIS_KEYS.HOST_DISCONNECT(eventId),
      ],
    );

    const roomName = `event_${eventId}`;
    this.server.to(roomName).emit(WS_EVENTS.ENDED, { reason: 'host_ended' });
    this.server.in(roomName).socketsLeave(roomName);

    return { event: 'ended', eventId };
  }
}
