import {
  OnGatewayConnection,
  OnGatewayDisconnect,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Logger, UseGuards } from '@nestjs/common';
import { Server, Socket } from 'socket.io';
import { WsAuthGuard } from '../websockets/guards/ws-auth.guard';
import { WsThrottlerGuard } from '../websockets/guards/ws-throttler.guard';
import { SocketAuthService } from '../websockets/socket-auth.service';
import {
  buildNotificationRoom,
  NOTIFICATION_NEW_EVENT,
} from './notifications.constants';
import type { NotificationResponseDto } from './dto/notification-response.dto';

@WebSocketGateway({ path: '/ws', cors: true })
@UseGuards(WsAuthGuard, WsThrottlerGuard)
export class NotificationsGateway
  implements OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  server!: Server;

  private readonly logger = new Logger(NotificationsGateway.name);

  constructor(private readonly socketAuthService: SocketAuthService) {}

  async handleConnection(client: Socket) {
    const user = this.socketAuthService.getUser(client);
    if (!user) {
      client.disconnect(true);
      return;
    }

    const roomName = buildNotificationRoom(user.id);
    try {
      await client.join(roomName);
      this.logger.log(
        `Socket connected: id=${client.id} userId=${user.id} room=${roomName}`,
      );
    } catch (error: unknown) {
      this.logger.error(
        `Failed to join room ${roomName} for socket ${client.id}: ${error instanceof Error ? error.message : 'Unknown error'}`,
      );
      client.disconnect(true);
    }
  }

  handleDisconnect(client: Socket) {
    const user = this.socketAuthService.getUser(client);
    this.logger.log(
      `Socket disconnected: id=${client.id}${user ? ` userId=${user.id}` : ''}`,
    );
  }

  emitNewNotification(
    userId: string,
    notification: NotificationResponseDto,
  ): void {
    const roomName = buildNotificationRoom(userId);
    this.server.to(roomName).emit(NOTIFICATION_NEW_EVENT, notification);
  }
}
