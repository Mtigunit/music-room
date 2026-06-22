import {
  ConnectedSocket,
  MessageBody,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
  WsException,
  OnGatewayDisconnect,
} from '@nestjs/websockets';
import {
  Logger,
  UseGuards,
  forwardRef,
  Inject,
  UsePipes,
  ValidationPipe,
} from '@nestjs/common';
import { Server, Socket } from 'socket.io';
import { WsAuthGuard } from '../websockets/guards/ws-auth.guard';
import { WsThrottlerGuard } from '../websockets/guards/ws-throttler.guard';
import { EventStatus, PlaybackStatus } from '@prisma/client';
import { getPosition, EventsService } from './events.service';
import { EventsRepository } from './events.repository';
import { PlaybackPlayDto } from './dto/playback-play.dto';
import { PlaybackPauseDto } from './dto/playback-pause.dto';
import { PlaybackNextDto } from './dto/playback-next.dto';
import { EventRoomDto } from './dto/event-room.dto';
import { WsUser } from '../websockets/decorators/ws-user.decorator';
import type { SocketUser } from '../websockets/socket-auth.service';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { WS_EVENTS, REDIS_KEYS, BULL_QUEUES } from './events.constants';
import { RedisService } from '../redis/redis.service';
import { EventEmitter2, OnEvent } from '@nestjs/event-emitter';
import { AUDIT_LOG_EVENT, AuditAction } from '../audit-log/audit-log.constants';
import { createAuditLogEvent } from '../audit-log/audit-log.event';
import { ClientMeta } from '../common/decorators/client-meta.decorator';
import { ClientMetaDto } from '../common/dto/client-meta.dto';
import { DelegationsRepository } from '../delegations/delegations.repository';
import { DelegationResponseDto } from '../delegations/dto/delegation-response.dto';
import { INTERNAL_EVENTS } from './events.constants';

@UsePipes(
  new ValidationPipe({
    transform: true,
    whitelist: true,
    exceptionFactory: (errors) =>
      new WsException(
        errors.map((e) => Object.values(e.constraints ?? {})).flat(),
      ),
  }),
)
@WebSocketGateway({ path: '/ws', cors: true })
@UseGuards(WsAuthGuard, WsThrottlerGuard)
export class EventsGateway implements OnGatewayDisconnect {
  @WebSocketServer()
  server!: Server;

  private readonly logger = new Logger(EventsGateway.name);

  constructor(
    private readonly redisService: RedisService,
    private readonly eventEmitter: EventEmitter2,
    @InjectQueue(BULL_QUEUES.EVENT_TIMEOUTS)
    private readonly eventTimeoutsQueue: Queue,
    @Inject(forwardRef(() => EventsService))
    private readonly eventsService: EventsService,
    private readonly eventsRepository: EventsRepository,
    private readonly delegationsRepository: DelegationsRepository,
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
      const currentTrack = await this.eventsRepository.getCurrentTrackPayload(
        disconnectResult.currentTrackId,
      );
      this.server
        .to(`event_${disconnectResult.eventId}`)
        .emit(WS_EVENTS.PLAYBACK_STATUS, {
          status: PlaybackStatus.PAUSED,
          currentTrack:
            currentTrack === null
              ? null
              : {
                  ...currentTrack,
                  pausedPlaybackPositionMs: disconnectResult.pausedPosition,
                  currentTrackStartedAt: null,
                },
        });
    }
  }

  private async isHostInRoom(
    roomName: string,
    hostSocketId: string,
  ): Promise<boolean> {
    const sockets = await this.server.in(roomName).fetchSockets();
    return sockets.some((socket) => socket.id === hostSocketId);
  }

  @SubscribeMessage(WS_EVENTS.JOIN)
  async handleEventJoin(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: EventRoomDto,
    @WsUser() user: SocketUser,
  ) {
    const userId = user.id;
    const eventId = payload.eventId;

    try {
      const event = await this.eventsService.findOne(eventId, userId)!; // Ensure event exists and is accessible, will throw if not
      if (event.host?.id === userId)
        throw new WsException(
          'Forbidden: Host must use host_join to join an event',
        );
      if (event.status === EventStatus.ENDED)
        throw new WsException('Event has already ended');
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
    } catch (error: unknown) {
      this.logger.error(
        `Failed to fetch event ${eventId} for user ${userId} | Error: ${error instanceof Error ? error.message : 'Unknown error'}`,
      );
      throw new WsException(
        error instanceof Error ? error.message : 'Unknown error',
      );
    }
  }

  @SubscribeMessage(WS_EVENTS.HOST_JOIN)
  async handleHostJoin(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: EventRoomDto,
    @WsUser() user: SocketUser,
  ) {
    const eventId = payload.eventId;
    const userId = user.id;

    // Single device capability enforcement
    const redisClient = this.redisService.getClient();
    const storedSocketId = await redisClient.get(
      REDIS_KEYS.HOST_SOCKET(eventId),
    );

    if (storedSocketId && storedSocketId !== client.id) {
      // Use fetchSockets() to check across all instances when using Redis Adapter
      const sockets = await this.server.in(storedSocketId).fetchSockets();
      if (sockets.length > 0) {
        throw new WsException(
          'Forbidden: Host is already connected from another device',
        );
      }
    }

    try {
      const event = await this.eventsService.findOne(eventId, userId);
      if (event.host?.id !== userId)
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
    } catch (error: unknown) {
      this.logger.error(
        `Failed to fetch event ${eventId} for host ${userId} | Error: ${error instanceof Error ? error.message : 'Unknown error'}`,
      );
      throw new WsException(
        error instanceof Error ? error.message : 'Unknown error',
      );
    }
  }

  private async handleHostRejoined(
    eventId: string,
    userId: string,
    socketId: string,
  ) {
    const redisClient = this.redisService.getClient();
    await redisClient.set(REDIS_KEYS.HOST_SOCKET(eventId), socketId);

    const softJob = await this.eventTimeoutsQueue.getJob(`soft-${eventId}`);
    const hardJob = await this.eventTimeoutsQueue.getJob(`hard-${eventId}`);

    if (softJob || hardJob) {
      this.logger.log(
        `Host ${userId} rejoined event ${eventId} in time, canceling timeouts.`,
      );

      if (softJob) {
        await softJob.remove().catch((error: Error) => {
          this.logger.error(
            `Failed to remove soft timeout job for event ${eventId} | Error: ${error instanceof Error ? error.message : 'Unknown error'}`,
          );
        });
      }

      if (hardJob) {
        await hardJob.remove().catch((error: Error) => {
          this.logger.error(
            `Failed to remove hard timeout job for event ${eventId} | Error: ${error instanceof Error ? error.message : 'Unknown error'}`,
          );
        });
      }

      const roomName = `event_${eventId}`;
      this.server
        .to(roomName)
        .emit(WS_EVENTS.HOST_RECONNECTED, { hostId: userId });
    }
  }

  @SubscribeMessage(WS_EVENTS.LEAVE)
  async handleEventLeave(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: EventRoomDto,
    @WsUser() user: SocketUser,
  ) {
    const eventId = payload.eventId;
    const userId = user.id;

    try {
      const event = await this.eventsService.findOne(eventId, userId);
      if (event.host?.id === userId)
        throw new WsException(
          'Forbidden: Host must use host_leave to leave an event',
        );
      const roomName = `event_${eventId}`;
      await client.leave(roomName);
      this.logger.log(`Client ${client.id} left room ${roomName}`);
      this.broadcastRoomCount(roomName);

      return { event: 'left', eventId };
    } catch (error: unknown) {
      this.logger.error(
        `Failed to fetch event ${eventId} for user ${userId} | Error: ${error instanceof Error ? error.message : 'Unknown error'}`,
      );
      throw new WsException(
        error instanceof Error ? error.message : 'Unknown error',
      );
    }
  }

  @SubscribeMessage(WS_EVENTS.HOST_LEAVE)
  async handleHostLeave(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: EventRoomDto,
    @WsUser() user: SocketUser,
  ) {
    const eventId = payload.eventId;
    const userId = user.id;

    // Reject stale signals from disconnected/old devices
    const redisClient = this.redisService.getClient();
    const storedSocketId = await redisClient.get(
      REDIS_KEYS.HOST_SOCKET(eventId),
    );

    if (storedSocketId && storedSocketId !== client.id) {
      throw new WsException(
        'Forbidden: Mismatched device. You are not the active host.',
      );
    }

    try {
      const event = await this.eventsService.findOne(eventId, userId);
      if (event.host?.id !== userId)
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

        // Clear the host socket so they can immediately join from another device
        await redisClient.del(REDIS_KEYS.HOST_SOCKET(eventId));

        // Handle WebSocket concerns only
        const currentTrack = await this.eventsRepository.getCurrentTrackPayload(
          event.currentTrack?.id ?? null,
        );
        this.logger.log(
          `Emitting host_left for event ${eventId} with paused position ${position}ms`,
        );
        this.server.to(roomName).emit(WS_EVENTS.PLAYBACK_STATUS, {
          status: PlaybackStatus.PAUSED,
          currentTrack:
            currentTrack === null
              ? null
              : {
                  ...currentTrack,
                  pausedPlaybackPositionMs: position,
                  currentTrackStartedAt: null,
                },
        });
      }
      return { event: 'host_left', eventId };
    } catch (error: unknown) {
      this.logger.error(
        `Failed to fetch event ${eventId} for host ${userId} | Error: ${error instanceof Error ? error.message : 'Unknown error'}`,
      );
      throw new WsException(
        error instanceof Error ? error.message : 'Unknown error',
      );
    }
  }

  @SubscribeMessage(WS_EVENTS.START)
  async handleEventStart(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: EventRoomDto,
    @WsUser() user: SocketUser,
    @ClientMeta() meta: ClientMetaDto,
  ) {
    const eventId = payload.eventId;
    const userId = user.id;
    const socketId = client.id;
    try {
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
      const currentTrack = await this.eventsRepository.getCurrentTrackPayload(
        updatedEvent.currentTrackId,
      );
      this.server.to(roomName).emit(WS_EVENTS.PLAYBACK_STATUS, {
        status: PlaybackStatus.PAUSED,
        currentTrack:
          currentTrack === null
            ? null
            : {
                ...currentTrack,
                pausedPlaybackPositionMs: 0,
                currentTrackStartedAt: null,
              },
      });

      this.eventEmitter.emit(
        AUDIT_LOG_EVENT,
        createAuditLogEvent(userId, AuditAction.EVENT_START, meta, { eventId }),
      );

      return { event: 'started', eventId, status: EventStatus.LIVE };
    } catch (error: unknown) {
      const errorMessage =
        error instanceof Error ? error.message : 'Unknown error';
      throw new WsException(errorMessage);
    }
  }

  @SubscribeMessage(WS_EVENTS.END)
  async handleEventEnd(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: EventRoomDto,
    @WsUser() user: SocketUser,
    @ClientMeta() meta: ClientMetaDto,
  ) {
    const eventId = payload.eventId;
    const userId = user.id;
    try {
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
    } catch (error: unknown) {
      const errorMessage =
        error instanceof Error ? error.message : 'Unknown error';
      throw new WsException(errorMessage);
    }
  }

  @SubscribeMessage(WS_EVENTS.PLAYBACK_PLAY)
  async handlePlaybackPlay(
    @MessageBody() payload: PlaybackPlayDto,
    @WsUser() user: SocketUser,
    @ClientMeta() meta: ClientMetaDto,
  ) {
    try {
      const redisClient = this.redisService.getClient();
      const hostSocketId = await redisClient.get(
        REDIS_KEYS.HOST_SOCKET(payload.eventId),
      );

      if (
        !hostSocketId ||
        !(await this.isHostInRoom(`event_${payload.eventId}`, hostSocketId))
      ) {
        throw new WsException(
          'Host is not present — playback control unavailable',
        );
      }
      const result = await this.eventsService.play(
        payload.eventId,
        user.id,
        meta.deviceId,
      );
      this.eventEmitter.emit(
        AUDIT_LOG_EVENT,
        createAuditLogEvent(user.id, AuditAction.DELEGATED_PLAY, meta),
      );
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
    @ClientMeta() meta: ClientMetaDto,
  ) {
    try {
      const hostSocketId = await this.redisService
        .getClient()
        .get(REDIS_KEYS.HOST_SOCKET(payload.eventId));
      if (
        !hostSocketId ||
        !(await this.isHostInRoom(`event_${payload.eventId}`, hostSocketId))
      ) {
        throw new WsException(
          'Host is not present — playback control unavailable',
        );
      }
      const result = await this.eventsService.pause(
        payload.eventId,
        user.id,
        meta.deviceId,
      );
      this.eventEmitter.emit(
        AUDIT_LOG_EVENT,
        createAuditLogEvent(user.id, AuditAction.DELEGATED_PAUSE, meta),
      );
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
    @ClientMeta() meta: ClientMetaDto,
  ) {
    try {
      const hostSocketId = await this.redisService
        .getClient()
        .get(REDIS_KEYS.HOST_SOCKET(payload.eventId));
      if (
        !hostSocketId ||
        !(await this.isHostInRoom(`event_${payload.eventId}`, hostSocketId))
      ) {
        throw new WsException(
          'Host is not present — playback control unavailable',
        );
      }
      const result = await this.eventsService.next(
        payload.eventId,
        user.id,
        payload.trackId ?? null,
        meta.deviceId,
      );
      this.eventEmitter.emit(
        AUDIT_LOG_EVENT,
        createAuditLogEvent(user.id, AuditAction.DELEGATED_NEXT, meta),
      );
      return { event: 'playback_next', ...result };
    } catch (error: unknown) {
      const errorMessage =
        error instanceof Error ? error.message : 'Unknown error';
      throw new WsException(errorMessage);
    }
  }

  @OnEvent(INTERNAL_EVENTS.DELEGATION_INVITE_SENT)
  async handleDelegationInviteSent(payload: {
    eventId: string;
    delegateeId: string;
    delegationId: string;
    hostname: string;
    eventName: string;
  }) {
    const roomName = `event_${payload.eventId}`;
    const sockets = await this.server.in(roomName).fetchSockets();

    for (const socket of sockets) {
      if (
        (socket.data as { user?: { id: string } }).user?.id ===
        payload.delegateeId
      ) {
        socket.emit(WS_EVENTS.DELEGATE, {
          eventId: payload.eventId,
          delegationId: payload.delegationId,
          hostname: payload.hostname,
          eventName: payload.eventName,
        });
      }
    }
  }

  @OnEvent(INTERNAL_EVENTS.DELEGATION_REVOKED)
  async handleDelegationRevoked(payload: {
    eventId: string;
    delegateeId: string;
    hostname: string | null;
    eventName: string | null;
  }) {
    const roomName = `event_${payload.eventId}`;
    const sockets = await this.server.in(roomName).fetchSockets();

    for (const socket of sockets) {
      if (
        (socket.data as { user?: { id: string } }).user?.id ===
        payload.delegateeId
      ) {
        socket.emit(WS_EVENTS.DELEGATION_REMOVED, {
          eventId: payload.eventId,
          hostname: payload.hostname,
          eventName: payload.eventName,
          message: 'Host removed delegation for you',
        });
      }
    }
  }

  @SubscribeMessage(WS_EVENTS.DELEGATION_RESPONSE)
  async handleDelegationResponse(
    @MessageBody() payload: DelegationResponseDto,
    @WsUser() user: SocketUser,
    @ClientMeta() meta: ClientMetaDto,
  ) {
    try {
      if (meta.deviceId === 'unknown')
        throw new WsException('Invalid device ID');
      if (payload.accept) {
        const result = await this.delegationsRepository.activateById(
          payload.delegationId,
          meta.deviceId,
          user.id,
        );
        if (result.count === 0) {
          throw new WsException(
            'Delegation could not be activated. It may be invalid, already active, or not owned by this user.',
          );
        }
        this.eventEmitter.emit(
          AUDIT_LOG_EVENT,
          createAuditLogEvent(user.id, AuditAction.DELEGATION_ACCEPTED, meta),
        );
      }
    } catch (error: unknown) {
      throw new WsException(
        error instanceof Error ? error.message : 'Unknown error',
      );
    }
  }
}
