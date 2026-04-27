import { applyDecorators } from '@nestjs/common';
import { ApiHeader } from '@nestjs/swagger';

export function ApiClientMeta() {
  return applyDecorators(
    ApiHeader({
      name: 'x-platform',
      required: false,
      description: 'Client platform (e.g., ios, android, web)',
      schema: { default: 'unknown' },
    }),
    ApiHeader({
      name: 'x-device-model',
      required: false,
      description: 'Client device model or browser (e.g., iPhone 13, Chrome)',
      schema: { default: 'unknown' },
    }),
    ApiHeader({
      name: 'x-app-version',
      required: false,
      description: 'Client app version (e.g., 1.0.0)',
      schema: { default: 'unknown' },
    }),
  );
}
