import {
  ConnectedSocket,
  MessageBody,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
  WsException,
} from '@nestjs/websockets';
import { Logger, UseGuards } from '@nestjs/common';
import { Server, Socket } from 'socket.io';
import { WsAuthGuard } from '../websockets/guards/ws-auth.guard';
import { PrismaService } from '../prisma/prisma.service';
import { EventStatus, Visibility } from '@prisma/client';
import { WsUser } from '../websockets/decorators/ws-user.decorator';
import type { SocketUser } from '../websockets/socket-auth.service';

@WebSocketGateway({ path: '/ws', cors: true })
@UseGuards(WsAuthGuard)
export class EventsGateway {
  @WebSocketServer()
  server!: Server;

  private readonly logger = new Logger(EventsGateway.name);

  constructor(private readonly prisma: PrismaService) {}

  private getRoomCount(roomName: string): number {
    const room = this.server.sockets.adapter.rooms.get(roomName);
    return room ? room.size : 0;
  }

  private broadcastRoomCount(roomName: string) {
    const count = this.getRoomCount(roomName);
    this.server.to(roomName).emit('room:count', { room: roomName, count });
  }

  @SubscribeMessage('event:join')
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

    if (!event) {
      throw new WsException('Event not found');
    }

    if (event.status === EventStatus.ENDED) {
      throw new WsException('Event has already ended');
    }

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

    // Acknowledge the user about the event's current start status
    client.emit('event:start', {
      eventId,
      status: event.status,
      startDate: event.startDate,
    });

    return { event: 'joined', eventId, status: event.status };
  }

  async joinUserToRoom(userId: string, roomName: string) {
    const sockets = await this.server.fetchSockets();
    for (const socket of sockets) {
      const data = socket.data as { user?: SocketUser };
      if (data?.user?.id === userId) {
        socket.join(roomName);
        this.logger.log(
          `Forced joined socket ${socket.id} (User: ${userId}) to room ${roomName}`,
        );
        this.broadcastRoomCount(roomName);
      }
    }
  }

  @SubscribeMessage('event:leave')
  async handleEventLeave(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { eventId: string },
  ) {
    if (!payload?.eventId) {
      throw new WsException('eventId is required');
    }

    const event = await this.prisma.event.findUnique({
      where: { id: payload.eventId },
    });

    if (!event) {
      throw new WsException('Event not found');
    }

    const roomName = `event_${payload.eventId}`;
    await client.leave(roomName);
    this.logger.log(`Client ${client.id} left room ${roomName}`);
    this.broadcastRoomCount(roomName);

    return { event: 'left', eventId: payload.eventId };
  }
}
