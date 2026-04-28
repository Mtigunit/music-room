import './config/env-setup';
import { NestFactory } from '@nestjs/core';
import { ConfigService } from '@nestjs/config';
import { AppModule } from './app.module';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { GlobalExceptionFilter } from './common/filters/global-exception.filter';
import { Logger, ValidationPipe } from '@nestjs/common';
import { RedisIoAdapter } from './websockets/socket-io.adapter';

async function bootstrap() {
  const logger = new Logger('Bootstrap');
  const app = await NestFactory.create(AppModule);
  const configService = app.get(ConfigService);

  const redisIoAdapter = new RedisIoAdapter(app, configService);
  await redisIoAdapter.connectToRedis();
  app.useWebSocketAdapter(redisIoAdapter);

  let isShuttingDown = false;
  const shutdown = async (signal: string) => {
    if (isShuttingDown) {
      return;
    }
    isShuttingDown = true;

    logger.log(`Received ${signal}; shutting down...`);
    try {
      await app.close();
    } catch (error: unknown) {
      const stack = error instanceof Error ? error.stack : undefined;
      logger.error('Error closing Nest application', stack);
    }

    try {
      await redisIoAdapter.disconnectFromRedis();
    } catch (error: unknown) {
      const stack = error instanceof Error ? error.stack : undefined;
      logger.error('Error disconnecting Socket.io Redis adapter', stack);
    }

    process.exit(0);
  };

  process.once('SIGINT', () => {
    void shutdown('SIGINT');
  });
  process.once('SIGTERM', () => {
    void shutdown('SIGTERM');
  });

  app.useGlobalFilters(new GlobalExceptionFilter());
  app.useGlobalPipes(
    new ValidationPipe({
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  const config = new DocumentBuilder()
    .setTitle('Music Room API')
    .setDescription('The core backend for the Music Room application')
    .setVersion('1.0')
    .addBearerAuth()
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document);

  app.enableCors();

  const port = configService.get<number>('API_PORT', 3000);
  await app.listen(port);
  logger.log(`Listening on port ${port}`);
}
bootstrap().catch((error) => {
  const logger = new Logger('Bootstrap');
  const stack = error instanceof Error ? error.stack : undefined;
  logger.error('Application bootstrap failed', stack);
  process.exit(1);
});
