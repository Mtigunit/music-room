import { Module, forwardRef } from '@nestjs/common';
import { FollowsService } from './follows.service';
import { FollowsController } from './follows.controller';
import { FollowsRepository } from './follows.repository';
import { PrismaModule } from '../prisma/prisma.module';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [PrismaModule, forwardRef(() => UsersModule)],
  controllers: [FollowsController],
  providers: [FollowsService, FollowsRepository],
  exports: [FollowsService],
})
export class FollowsModule {}
