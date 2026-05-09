import { createParamDecorator, ExecutionContext, Logger } from '@nestjs/common';
import { ClientMetaDto } from '../dto/client-meta.dto';
import type { Request } from 'express';

const logger = new Logger('ClientMetaDecorator');

/**
 * Normalizes a header value to a single string.
 * If multiple headers are sent (array), it takes the first one.
 */
function normalizeHeader(
  value: string | string[] | undefined,
): string | undefined {
  if (Array.isArray(value)) {
    return value[0];
  }
  return value;
}

export const ClientMeta = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): ClientMetaDto => {
    let platform: string | undefined;
    let deviceModel: string | undefined;
    let deviceId: string | undefined;
    let appVersion: string | undefined;
    let ipAddress: string | undefined;
    const type = ctx.getType();

    if (type === 'http') {
      const request = ctx.switchToHttp().getRequest<Request>();
      platform = normalizeHeader(request.headers['x-platform']);
      deviceModel = normalizeHeader(request.headers['x-device-model']);
      deviceId = normalizeHeader(request.headers['x-device-id']);
      appVersion = normalizeHeader(request.headers['x-app-version']);
      ipAddress = request.ip || request.socket?.remoteAddress;
    } else if (type === 'ws') {
      interface WsClientLike {
        handshake?: {
          headers?: Record<string, string | string[] | undefined>;
          address?: string;
        };
      }
      const client = ctx.switchToWs().getClient<WsClientLike>();
      // Socket.io stores headers in handshake.headers
      platform = normalizeHeader(client.handshake?.headers?.['x-platform']);
      deviceModel = normalizeHeader(
        client.handshake?.headers?.['x-device-model'],
      );
      deviceId = normalizeHeader(client.handshake?.headers?.['x-device-id']);
      appVersion = normalizeHeader(
        client.handshake?.headers?.['x-app-version'],
      );
      ipAddress = client.handshake?.address;
    }

    // Graceful fallback logging for optional client metadata
    if (!platform || !deviceModel || !deviceId || !appVersion) {
      logger.debug(
        `Missing optional client metadata headers on ${type} request. ` +
          `Expected x-platform, x-device-model, x-device-id, x-app-version. Falling back to 'unknown'.`,
      );
    }

    return {
      platform: platform || 'unknown',
      deviceModel: deviceModel || 'unknown',
      deviceId: deviceId || 'unknown',
      appVersion: appVersion || 'unknown',
      ipAddress: ipAddress,
    };
  },
);
