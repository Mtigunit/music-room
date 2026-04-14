import { Module, Global } from '@nestjs/common';
import { EventRegistryService } from './event-registry.service';
import { GenericWebsocketGateway } from './generic-websocket.gateway';
import { RedisModule } from '../redis/redis.module';

@Global()
@Module({
  imports: [RedisModule],
  providers: [EventRegistryService, GenericWebsocketGateway],
  exports: [EventRegistryService],
})
export class WebsocketsModule {}
