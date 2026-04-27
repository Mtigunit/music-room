import { createParamDecorator, ExecutionContext, Logger } from '@nestjs/common';
import { ClientMetaDto } from '../dto/client-meta.dto';
import type { Request } from 'express';

const logger = new Logger('ClientMetaDecorator');

export const ClientMeta = createParamDecorator(
  (data: unknown, ctx: ExecutionContext): ClientMetaDto => {
    let platform: string | undefined;
    let deviceModel: string | undefined;
    let appVersion: string | undefined;
    let ipAddress: string | undefined;
    let url = 'unknown';

    const type = ctx.getType();

    if (type === 'http') {
      const request = ctx.switchToHttp().getRequest<Request>();
      platform = request.headers['x-platform'] as string;
      deviceModel = request.headers['x-device-model'] as string;
      appVersion = request.headers['x-app-version'] as string;
      ipAddress = request.ip || request.socket?.remoteAddress;
      url = request.url;
    } else if (type === 'ws') {
      interface WsClientLike {
        handshake?: {
          headers?: Record<string, string | string[] | undefined>;
          address?: string;
        };
      }
      const client = ctx.switchToWs().getClient<WsClientLike>();
      // Socket.io stores headers in handshake.headers
      platform = client.handshake?.headers?.['x-platform'] as string;
      deviceModel = client.handshake?.headers?.['x-device-model'] as string;
      appVersion = client.handshake?.headers?.['x-app-version'] as string;
      ipAddress = client.handshake?.address;
      url = 'WebSocket';
    }

    // Graceful fallback warning
    if (!platform || !deviceModel || !appVersion) {
      logger.warn(
        `Missing client metadata headers on ${type} request to ${url}. ` +
          `Expected x-platform, x-device-model, x-app-version. Falling back to 'unknown'.`,
      );
    }

    return {
      platform: platform || 'unknown',
      deviceModel: deviceModel || 'unknown',
      appVersion: appVersion || 'unknown',
      ipAddress: ipAddress,
    };
  },
);
