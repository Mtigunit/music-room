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
import { Visibility } from '@prisma/client';
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

    if (event.hostId === userId) {
      throw new WsException('Host must use event:start to join the event');
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

    return { event: 'joined', eventId };
  }

  @SubscribeMessage('event:leave')
  async handleEventLeave(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { eventId: string },
    @WsUser() user: SocketUser,
  ) {
    if (!payload?.eventId) {
      throw new WsException('eventId is required');
    }

    const event = await this.prisma.event.findUnique({
      where: { id: payload.eventId },
    });

    if (event && event.hostId === user.id) {
      throw new WsException('Host must use event:end to end the event');
    }

    const roomName = `event_${payload.eventId}`;
    await client.leave(roomName);
    this.logger.log(`Client ${client.id} left room ${roomName}`);
    this.broadcastRoomCount(roomName);

    return { event: 'left', eventId: payload.eventId };
  }

  @SubscribeMessage('event:start')
  async handleEventStart(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { eventId: string },
    @WsUser() user: SocketUser,
  ) {
    if (!payload?.eventId) {
      throw new WsException('eventId is required');
    }

    const eventId = payload.eventId;
    const event = await this.prisma.event.findUnique({
      where: { id: eventId },
    });

    if (!event) {
      throw new WsException('Event not found');
    }

    if (event.hostId !== user.id) {
      throw new WsException('Forbidden: Only host can start the room');
    }

    const roomName = `event_${eventId}`;
    await client.join(roomName);
    this.logger.log(`Host ${user.id} started/joined room ${roomName}`);

    // Emit event:start topic to the room
    this.server.to(roomName).emit('event:start', { eventId });
    this.broadcastRoomCount(roomName);

    return { event: 'started', eventId };
  }

  @SubscribeMessage('event:end')
  async handleEventEnd(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { eventId: string },
    @WsUser() user: SocketUser,
  ) {
    if (!payload?.eventId) {
      throw new WsException('eventId is required');
    }

    const eventId = payload.eventId;
    const event = await this.prisma.event.findUnique({
      where: { id: eventId },
    });

    if (!event) {
      throw new WsException('Event not found');
    }

    if (event.hostId !== user.id) {
      throw new WsException('Forbidden: Only host can end the event');
    }

    const roomName = `event_${eventId}`;

    // Notify clients before disconnecting
    this.server.to(roomName).emit('event:ended', { eventId });

    // Make everyone leave the room
    this.server.in(roomName).socketsLeave(roomName);
    this.logger.log(
      `Host ${user.id} ended room ${roomName} and kicked all subscribers`,
    );

    // Wait for the leave to process, although socketsLeave is immediate and doesn't trigger leave events per socket in adapter rooms immediately sometimes,
    // broadcasting 0 is safer.
    this.broadcastRoomCount(roomName);

    return { event: 'ended', eventId };
  }
}
