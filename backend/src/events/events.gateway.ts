import {
  ConnectedSocket,
  MessageBody,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
  WsException,
  OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Logger, UseGuards, forwardRef, Inject } from '@nestjs/common';
import { Server, Socket } from 'socket.io';
import { WsAuthGuard } from '../websockets/guards/ws-auth.guard';
import { WsThrottlerGuard } from '../websockets/guards/ws-throttler.guard';
import { PrismaService } from '../prisma/prisma.service';
import { EventStatus, Visibility, PlaybackStatus } from '@prisma/client';
import { getPosition, EventsService } from './events.service';
import { EventsRepository } from './events.repository';
import { PlaybackPlayDto } from './dto/playback-play.dto';
import { PlaybackPauseDto } from './dto/playback-pause.dto';
import { PlaybackNextDto } from './dto/playback-next.dto';
import { WsUser } from '../websockets/decorators/ws-user.decorator';
import type { SocketUser } from '../websockets/socket-auth.service';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { WS_EVENTS, REDIS_KEYS, BULL_QUEUES } from './events.constants';
import { RedisService } from '../redis/redis.service';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { AUDIT_LOG_EVENT, AuditAction } from '../audit-log/audit-log.constants';
import { createAuditLogEvent } from '../audit-log/audit-log.event';
import { ClientMeta } from '../common/decorators/client-meta.decorator';
import { ClientMetaDto } from '../common/dto/client-meta.dto';

@WebSocketGateway({ path: '/ws', cors: true })
@UseGuards(WsAuthGuard, WsThrottlerGuard)
export class EventsGateway implements OnGatewayDisconnect {
  @WebSocketServer()
  server!: Server;

  private readonly logger = new Logger(EventsGateway.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly redisService: RedisService,
    private readonly eventEmitter: EventEmitter2,
    @InjectQueue(BULL_QUEUES.EVENT_TIMEOUTS)
    private readonly eventTimeoutsQueue: Queue,
    @Inject(forwardRef(() => EventsService))
    private readonly eventsService: EventsService,
    private readonly eventsRepository: EventsRepository,
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

    // Delegate business logic to service
    const disconnectResult = await this.eventsService.handleHostDisconnect(
      user.id,
      client.id,
    );

    if (disconnectResult) {
      // Handle WebSocket concerns only
      this.server
        .to(`event_${disconnectResult.eventId}`)
        .emit(WS_EVENTS.PLAYBACK_STATUS, {
          status: PlaybackStatus.PAUSED,
          currentTrackId: disconnectResult.currentTrackId,
          pausedPlaybackPositionMs: disconnectResult.pausedPosition,
        });
    }
  }

  private async removeExistingTimeoutJob(jobId: string) {
    const existingJob = await this.eventTimeoutsQueue.getJob(jobId);
    if (existingJob) {
      existingJob.remove().catch((error: Error) => {
        this.logger.error(
          `Failed to remove existing timeout job with ID ${jobId} | Error: ${error instanceof Error ? error.message : 'Unknown error'}`,
        );
      });
    }
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
    if (event.status !== EventStatus.LIVE)
      throw new WsException('Forbidden: Host can only join live events');

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
      if (hardJob)
        await hardJob.remove().catch((error: Error) => {
          this.logger.error(
            `Failed to remove hard timeout job for event ${eventId} | Error: ${error instanceof Error ? error.message : 'Unknown error'}`,
          );
        });

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
      select: {
        id: true,
        status: true,
        hostId: true,
        currentTrackId: true,
        playbackStatus: true,
        currentTrackStartedAt: true,
        pausedPlaybackPositionMs: true,
      },
    });

    if (!event) throw new WsException('Event not found');
    if (event.hostId !== userId)
      throw new WsException('Forbidden: Only host can use host_leave');

    const roomName = `event_${eventId}`;
    await client.leave(roomName);
    this.logger.log(`Host ${client.id} explicitly left room ${roomName}`);
    this.broadcastRoomCount(roomName);

    if (event.status === EventStatus.LIVE) {
      // Delegate business logic to service
      const position = getPosition(event);
      await this.eventsService.startHostGracePeriod(eventId, userId);
      await this.eventsRepository.pausePlayback(event.id, position);

      // Handle WebSocket concerns only
      this.server.to(roomName).emit(WS_EVENTS.PLAYBACK_STATUS, {
        status: PlaybackStatus.PAUSED,
        currentTrackId: event.currentTrackId,
        pausedPlaybackPositionMs: position,
      });
    }

    return { event: 'host_left', eventId };
  }

  @SubscribeMessage(WS_EVENTS.START)
  async handleEventStart(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { eventId: string },
    @WsUser() user: SocketUser,
    @ClientMeta() meta: ClientMetaDto,
  ) {
    if (!payload?.eventId) throw new WsException('eventId is required');

    const eventId = payload.eventId;
    const userId = user.id;
    const socketId = client.id;

    // Delegate business logic to service
    const updatedEvent = await this.eventsService.startEvent(
      eventId,
      userId,
      socketId,
    );

    // Handle WebSocket concerns only
    const roomName = `event_${eventId}`;
    await client.join(roomName);

    this.server.to(roomName).emit(WS_EVENTS.STARTED, {
      eventId,
      status: EventStatus.LIVE,
      startDate: updatedEvent.startDate,
      hostId: userId,
    });
    this.broadcastRoomCount(roomName);

    this.server.to(roomName).emit(WS_EVENTS.PLAYBACK_STATUS, {
      status: PlaybackStatus.PAUSED,
      currentTrackId: updatedEvent.currentTrackId,
      pausedPlaybackPositionMs: 0,
    });

    this.eventEmitter.emit(
      AUDIT_LOG_EVENT,
      createAuditLogEvent(userId, AuditAction.EVENT_START, meta, { eventId }),
    );

    return { event: 'started', eventId, status: EventStatus.LIVE };
  }

  @SubscribeMessage(WS_EVENTS.END)
  async handleEventEnd(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { eventId: string },
    @WsUser() user: SocketUser,
    @ClientMeta() meta: ClientMetaDto,
  ) {
    if (!payload?.eventId) throw new WsException('eventId is required');

    const eventId = payload.eventId;
    const userId = user.id;

    // Delegate business logic to service
    await this.eventsService.endEvent(eventId, userId);

    // Handle WebSocket concerns only
    const roomName = `event_${eventId}`;
    this.server.to(roomName).emit(WS_EVENTS.ENDED, { reason: 'host_ended' });
    this.server.in(roomName).socketsLeave(roomName);

    this.eventEmitter.emit(
      AUDIT_LOG_EVENT,
      createAuditLogEvent(userId, AuditAction.EVENT_END, meta, {
        eventId,
        reason: 'host_ended',
      }),
    );

    return { event: 'ended', eventId };
  }

  @SubscribeMessage(WS_EVENTS.PLAYBACK_PLAY)
  async handlePlaybackPlay(
    @MessageBody() payload: PlaybackPlayDto,
    @WsUser() user: SocketUser,
  ) {
    if (!payload?.eventId) throw new WsException('eventId is required');
    try {
      const result = await this.eventsService.play(payload.eventId, user.id);
      return { event: 'playback_play', ...result };
    } catch (error: unknown) {
      const errorMessage =
        error instanceof Error ? error.message : 'Unknown error';
      throw new WsException(errorMessage);
    }
  }

  @SubscribeMessage(WS_EVENTS.PLAYBACK_PAUSE)
  async handlePlaybackPause(
    @MessageBody() payload: PlaybackPauseDto,
    @WsUser() user: SocketUser,
  ) {
    if (!payload?.eventId) throw new WsException('eventId is required');
    try {
      const result = await this.eventsService.pause(payload.eventId, user.id);
      return { event: 'playback_pause', ...result };
    } catch (error: unknown) {
      const errorMessage =
        error instanceof Error ? error.message : 'Unknown error';
      throw new WsException(errorMessage);
    }
  }

  @SubscribeMessage(WS_EVENTS.PLAYBACK_NEXT)
  async handlePlaybackNext(
    @MessageBody() payload: PlaybackNextDto,
    @WsUser() user: SocketUser,
  ) {
    if (!payload?.eventId) throw new WsException('eventId is required');
    try {
      const result = await this.eventsService.next(
        payload.eventId,
        user.id,
        payload.trackId ?? null,
      );
      return { event: 'playback_next', ...result };
    } catch (error: unknown) {
      const errorMessage =
        error instanceof Error ? error.message : 'Unknown error';
      throw new WsException(errorMessage);
    }
  }
}
