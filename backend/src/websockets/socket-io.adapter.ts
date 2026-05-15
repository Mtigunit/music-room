import { IoAdapter } from '@nestjs/platform-socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import { createClient, type RedisClientType } from 'redis';
import { ConfigService } from '@nestjs/config';
import { INestApplicationContext, Logger } from '@nestjs/common';
import { type Server, type ServerOptions } from 'socket.io';
import { HandshakeMiddleware } from './handshake.middleware';

export class RedisIoAdapter extends IoAdapter {
  private adapterConstructor?: ReturnType<typeof createAdapter>;
  private pubClient?: RedisClientType;
  private subClient?: RedisClientType;
  private readonly logger = new Logger(RedisIoAdapter.name);
  private readonly appContext: INestApplicationContext;

  constructor(
    app: INestApplicationContext,
    private readonly configService: ConfigService,
  ) {
    super(app);
    this.appContext = app;
  }

  async connectToRedis(): Promise<void> {
    const url = this.configService.get<string>('REDIS_URL');
    const host = this.configService.get<string>('REDIS_HOST', 'redis');
    const port = this.configService.get<number>('REDIS_PORT', 6379);
    const redisUrl = url ?? `redis://${host}:${port}`;

    this.pubClient = createClient({ url: redisUrl });
    this.subClient = this.pubClient.duplicate();

    this.pubClient.on('error', (err) => {
      this.logger.error('Socket.io Redis pub client error', err);
    });
    this.subClient.on('error', (err) => {
      this.logger.error('Socket.io Redis sub client error', err);
    });

    await Promise.all([this.pubClient.connect(), this.subClient.connect()]);
    this.adapterConstructor = createAdapter(this.pubClient, this.subClient);
    this.logger.log('Socket.io Redis adapter connected');
  }

  async disconnectFromRedis(): Promise<void> {
    const pubClient = this.pubClient;
    const subClient = this.subClient;

    this.adapterConstructor = undefined;
    this.pubClient = undefined;
    this.subClient = undefined;

    const shutdownClient = async (
      client: RedisClientType | undefined,
      name: 'pub' | 'sub',
    ): Promise<void> => {
      if (!client) {
        return;
      }

      try {
        if (client.isOpen) {
          await client.quit();
        } else {
          await client.disconnect();
        }
      } catch (error: unknown) {
        const message =
          error instanceof Error ? error.message : 'Unknown Redis error';
        const stack = error instanceof Error ? error.stack : undefined;

        this.logger.error(
          `Socket.io Redis ${name} client shutdown error: ${message}`,
          stack,
        );

        try {
          await client.disconnect();
        } catch {
          // ignore best-effort disconnect errors
        }
      }
    };

    await Promise.all([
      shutdownClient(pubClient, 'pub'),
      shutdownClient(subClient, 'sub'),
    ]);

    this.logger.log('Socket.io Redis adapter disconnected');
  }

  override createIOServer(port: number, options?: ServerOptions): Server {
    // const server = super.createIOServer(port, options) as Server;
    const server = super.createIOServer(port, {
      ...options,
      pingInterval: 10000, // send ping every 10s
      pingTimeout: 5000, // wait 5s for pong before disconnecting
    }) as Server;

    const handshake = this.appContext.get(HandshakeMiddleware);
    server.use(handshake.use());

    if (this.adapterConstructor) {
      server.adapter(this.adapterConstructor);
    } else {
      this.logger.warn(
        'Socket.io Redis adapter not initialized; running without adapter',
      );
    }

    return server;
  }
}
