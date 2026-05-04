import { Module, BadRequestException } from '@nestjs/common';
import { MulterModule } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import * as fs from 'fs';
import * as crypto from 'crypto';
import { UsersService } from './users.service';
import { UserRepository } from './user.repository';
import { PrismaModule } from '../prisma/prisma.module';
import { UsersController } from './users.controller';
import mime from 'mime-types';
import { FollowsModule } from '../follows/follows.module';

@Module({
  imports: [
    PrismaModule,
    FollowsModule,
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
        destination: (_req, _file, cb) => {
          const uploadPath = './uploads';
          fs.mkdir(uploadPath, { recursive: true }, (error) => {
            if (error) {
              return cb(error, uploadPath);
            }
            cb(null, uploadPath);
          });
        },
        filename: (_req, file, cb) => {
          const ext = mime.extension(file.mimetype);
          if (!ext) {
            return cb(
              new BadRequestException('Only image files are allowed!'),
              '',
            );
          }
          cb(null, `avatar-${crypto.randomUUID()}.${ext}`);
        },
      }),
    }),
  ],
  controllers: [UsersController],
  providers: [UsersService, UserRepository],
  exports: [UsersService],
})
export class UsersModule {}
