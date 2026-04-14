import { WebSocket } from 'ws';

export interface WSMessage {
  event: string;
  payload: any;
  roomId?: string;
}

export interface WSContext {
  ws: WebSocket;
  userId: string;
  roomId?: string;
  redisClient: import('ioredis').Redis; // Using the Redis client from your RedisService
  broadcast: (roomId: string, message: WSMessage) => void;
}

export type EventHandler = (ctx: WSContext, payload: any) => Promise<void>;
