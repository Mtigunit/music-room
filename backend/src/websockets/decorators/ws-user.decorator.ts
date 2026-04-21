import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { WsException } from '@nestjs/websockets';
import type { Socket } from 'socket.io';
import { SocketUser } from '../socket-auth.service';

/**
 * Custom decorator to extract the authenticated user from a WebSocket client.
 * Assumes WsAuthGuard or equivalent has already populated client.data.user.
 * Falls back to throwing a WsException if the user is missing.
 */
export const WsUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): SocketUser => {
    const client = ctx.switchToWs().getClient<Socket>();
    const user = (client.data as { user?: SocketUser })?.user;

    if (!user) {
      throw new WsException('Unauthorized access to WebSocket resource');
    }

    return user;
  },
);
