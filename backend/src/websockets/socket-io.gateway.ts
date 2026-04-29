import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Logger, UseGuards } from '@nestjs/common';
import { Server, Socket } from 'socket.io';
import { SocketAuthService } from './socket-auth.service';
import { WsAuthGuard } from './guards/ws-auth.guard';
import { WsThrottlerGuard } from './guards/ws-throttler.guard';

interface RoomPayload {
  roomId: string;
}

/**
 * Socket.io gateway for baseline WS functionality.
 *
 * Transport
 * - Path: `/ws`
 *
 * Authentication
 * - Connections are expected to be authenticated at handshake time.
 * - Client must provide `auth.token` (JWT) when connecting.
 * - Unauthorized sockets are rejected during the handshake.
 *
 * Events (client -> server)
 * - `room:join`  { roomId: string }
 * - `room:leave` { roomId: string }
 * - `ping`       (no payload)
 *
 * Events (server -> client)
 * - `room:joined` { roomId: string }
 * - `room:left`   { roomId: string }
 * - `room:error`  { message: string }
 * - `pong`        { serverTime: string }
 */
@WebSocketGateway({ path: '/ws', cors: true })
@UseGuards(WsAuthGuard, WsThrottlerGuard)
export class SocketIoGateway
  implements OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  server!: Server;

  private readonly logger = new Logger(SocketIoGateway.name);

  constructor(private readonly socketAuthService: SocketAuthService) {}

  /**
   * Lifecycle hook invoked after a client successfully connects.
   *
   * Note: authentication should already be completed during handshake.
   */
  handleConnection(client: Socket) {
    const user = this.socketAuthService.getUser(client);
    this.logger.log(
      `Socket connected: id=${client.id}${user ? ` userId=${user.id}` : ''}`,
    );
  }

  /**
   * Lifecycle hook invoked when a client disconnects.
   */
  handleDisconnect(client: Socket) {
    const user = this.socketAuthService.getUser(client);
    this.logger.log(
      `Socket disconnected: id=${client.id}${user ? ` userId=${user.id}` : ''}`,
    );
  }

  /**
   * Client -> Server: `room:join`
   * Payload: `{ roomId: string }`
   *
   * Server -> Client:
   * - `room:joined` `{ roomId: string }` on success
   * - `room:error` `{ message: string }` when `roomId` is missing/blank
   */
  @SubscribeMessage('room:join')
  async handleJoinRoom(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: RoomPayload,
  ) {
    const roomId = payload?.roomId?.trim();
    if (!roomId) {
      client.emit('room:error', { message: 'roomId is required' });
      return;
    }

    await client.join(roomId);
    client.emit('room:joined', { roomId });
  }

  /**
   * Client -> Server: `room:leave`
   * Payload: `{ roomId: string }`
   *
   * Server -> Client:
   * - `room:left` `{ roomId: string }` on success
   * - `room:error` `{ message: string }` when `roomId` is missing/blank
   */
  @SubscribeMessage('room:leave')
  async handleLeaveRoom(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: RoomPayload,
  ) {
    const roomId = payload?.roomId?.trim();
    if (!roomId) {
      client.emit('room:error', { message: 'roomId is required' });
      return;
    }

    await client.leave(roomId);
    client.emit('room:left', { roomId });
  }

  /**
   * Client -> Server: `ping`
   *
   * Server -> Client: `pong` `{ serverTime: string }`
   */
  @SubscribeMessage('ping')
  handlePing(@ConnectedSocket() client: Socket) {
    client.emit('pong', { serverTime: new Date().toISOString() });
  }
}
