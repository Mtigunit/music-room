import {
  WebSocketGateway,
  WebSocketServer,
  OnGatewayConnection,
  OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Server, WebSocket } from 'ws';
import {
  Injectable,
  Logger,
  OnApplicationBootstrap,
  OnModuleDestroy,
} from '@nestjs/common';
import { EventRegistryService } from './event-registry.service';
import { WSMessage, WSContext } from './interfaces/websocket.interface';
import { RedisService } from '../redis/redis.service';
import { Redis } from 'ioredis';

@Injectable()
@WebSocketGateway({ path: '/ws', cors: true })
export class GenericWebsocketGateway
  implements
    OnGatewayConnection,
    OnGatewayDisconnect,
    OnApplicationBootstrap,
    OnModuleDestroy
{
  @WebSocketServer()
  server!: Server;

  private readonly logger = new Logger(GenericWebsocketGateway.name);

  // Local physical connection tracking
  private readonly rooms = new Map<string, Set<WebSocket>>();
  private readonly clients = new Map<WebSocket, string>();

  // Dedicated Redis clients for Pub/Sub to prevent blocking the main data client
  private pubClient!: Redis;
  private subClient!: Redis;

  constructor(
    private readonly eventRegistryService: EventRegistryService,
    private readonly redisService: RedisService,
  ) {}

  onApplicationBootstrap() {
    this.pubClient = this.redisService.getClient().duplicate();
    this.subClient = this.redisService.getClient().duplicate();

    // Subscribe to a global channels for broadcasting events across all backend instances
    void this.subClient.subscribe('ws-broadcast', (err: any) => {
      if (err)
        this.logger.error('Failed to subscribe to ws-broadcast channel', err);
    });

    this.subClient.on('message', (channel, payload) => {
      if (channel === 'ws-broadcast') {
        const data = JSON.parse(payload) as {
          roomId: string;
          message: WSMessage;
        };
        this.localBroadcast(data.roomId, data.message);
      }
    });
    this.logger.log(
      'Redis Pub/Sub initialized for cross-server WebSocket broadcasting',
    );
  }

  async onModuleDestroy() {
    await this.pubClient.quit();
    await this.subClient.quit();
  }

  handleConnection(client: WebSocket, ...args: any[]) {
    const req = args[0] as { headers: Record<string, string>; url?: string };

    // Browser WebSockets don't support custom headers, so we allow query params for testing/fallback
    const queryUserId = req.url
      ? new URLSearchParams(req.url.split('?')[1]).get('userId')
      : null;
    const userId = req.headers['x-user-id'] || queryUserId;

    if (!userId) {
      this.logger.warn(`Client connected without user ID.`);
      client.close();
      return;
    }

    this.clients.set(client, userId);
    this.logger.log(`Client connected: userId=${userId}`);

    client.on('message', (raw: Buffer) => {
      void (async () => {
        try {
          const messageHeader = JSON.parse(raw.toString()) as WSMessage;

          if (messageHeader.roomId) {
            this.handleJoinRoom(client, messageHeader.roomId);
          }

          const ctx: WSContext = {
            ws: client,
            userId: userId,
            roomId: messageHeader.roomId,
            redisClient: this.redisService.getClient(),
            broadcast: this.broadcast.bind(this),
          };

          await this.eventRegistryService.dispatch(ctx, messageHeader);
        } catch (err: unknown) {
          const errorMessage = err instanceof Error ? err.message : String(err);
          this.logger.error(
            `Error parsing or dispatching message: ${errorMessage}`,
          );
          client.send(
            JSON.stringify({
              event: 'error',
              payload: 'Invalid message format',
            }),
          );
        }
      })();
    });

    client.on('error', (error: Error) => {
      this.logger.error(`Client Error: ${error.message}`);
    });
  }

  handleDisconnect(client: WebSocket) {
    const userId = this.clients.get(client);
    this.logger.log(`Client disconnected: userId=${userId}`);
    this.clients.delete(client);

    this.rooms.forEach((clients, roomId) => {
      if (clients.has(client)) {
        clients.delete(client);

        // Remove presence from Redis atomically
        if (userId) {
          this.redisService
            .getClient()
            .srem(`room:${roomId}:users`, userId)
            .catch((err: any) => {
              this.logger.error(
                `Failed to remove presence for room ${roomId}: ${err instanceof Error ? err.message : String(err)}`,
              );
            });
        }

        if (clients.size === 0) {
          this.rooms.delete(roomId);
        }
      }
    });
  }

  // Called when an event handler does `ctx.broadcast(roomId, message)`.
  // Instead of broadcasting to just this server's memory map, publish to Redis Pub/Sub
  private broadcast(roomId: string, message: WSMessage) {
    this.pubClient
      .publish('ws-broadcast', JSON.stringify({ roomId, message }))
      .catch((err: any) => {
        this.logger.error(
          `Pub/Sub broadcast failed: ${err instanceof Error ? err.message : String(err)}`,
        );
      });
  }

  // The actual function that sends it to the TCP sockets connected to *this* specific Node process
  private localBroadcast(roomId: string, message: WSMessage) {
    const roomClients = this.rooms.get(roomId);
    if (!roomClients) return;

    roomClients.forEach((client) => {
      if (client.readyState === client.OPEN) {
        client.send(JSON.stringify(message));
      }
    });
  }

  private handleJoinRoom(client: WebSocket, roomId: string) {
    if (!this.rooms.has(roomId)) {
      this.rooms.set(roomId, new Set());
    }
    this.rooms.get(roomId)?.add(client);

    // Track user presence in Redis globally
    const userId = this.clients.get(client);
    if (userId) {
      this.redisService
        .getClient()
        .sadd(`room:${roomId}:users`, userId)
        .catch((err: any) => {
          this.logger.error(
            `Failed to add user presence for room ${roomId}: ${err instanceof Error ? err.message : String(err)}`,
          );
        });
    }
  }
}
