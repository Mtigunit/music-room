import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { UsersModule } from '../users/users.module';
import { SocketAuthService } from './socket-auth.service';
import { SocketIoGateway } from './socket-io.gateway';
import { WsAuthGuard } from './guards/ws-auth.guard';
import { WsThrottlerGuard } from './guards/ws-throttler.guard';
import { HandshakeMiddleware } from './handshake.middleware';

@Module({
  imports: [AuthModule, UsersModule],
  providers: [
    SocketAuthService,
    SocketIoGateway,
    WsAuthGuard,
    WsThrottlerGuard,
    HandshakeMiddleware,
  ],
  exports: [
    SocketAuthService,
    WsAuthGuard,
    WsThrottlerGuard,
    HandshakeMiddleware,
    SocketIoGateway,
  ],
})
export class WebsocketsModule {}
