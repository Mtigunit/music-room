import { Module, BadRequestException } from '@nestjs/common';
import { MulterModule } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname } from 'path';
import * as fs from 'fs';
import { EventsService } from './events.service';
import { EventsController } from './events.controller';
import { EventsRepository } from './events.repository';
import { EventsGateway } from './events.gateway';
import { PrismaModule } from '../prisma/prisma.module';
import { WebsocketsModule } from '../websockets/websockets.module';
import { TracksModule } from '../tracks/tracks.module';
import { BullModule } from '@nestjs/bullmq';
import { BULL_QUEUES } from './events.constants';
import { EventsProcessor } from './events.processor';
import { RedisModule } from '../redis/redis.module';

@Module({
  imports: [
    PrismaModule,
    WebsocketsModule,
    TracksModule,
    RedisModule,
    BullModule.registerQueue({
      name: BULL_QUEUES.EVENT_TIMEOUTS,
    }),
    MulterModule.register({
      limits: {
        fileSize: 2 * 1024 * 1024, // 2MB limit
      },
      fileFilter: (_req, file, cb) => {
        if (!file.mimetype.match(/\/(jpg|jpeg|png|gif|webp)$/)) {
          return cb(
            new BadRequestException('Only image files are allowed!'),
            false,
          );
        }
        cb(null, true);
      },
      storage: diskStorage({
        destination: (req, file, cb) => {
          const uploadPath = './uploads';
          fs.mkdir(uploadPath, { recursive: true }, (error) => {
            if (error) {
              return cb(error, uploadPath);
            }
            cb(null, uploadPath);
          });
        },
        filename: (req, file, cb) => {
          const uniqueSuffix =
            Date.now() + '-' + Math.round(Math.random() * 1e9);
          const ext = extname(file.originalname);
          cb(null, `${file.fieldname}-${uniqueSuffix}${ext}`);
        },
      }),
    }),
  ],
  controllers: [EventsController],
  providers: [EventsService, EventsRepository, EventsGateway, EventsProcessor],
})
export class EventsModule {}
