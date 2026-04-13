import { Module } from '@nestjs/common';
import { UsersService } from './users.service';
import { UserRepository } from './user.repository';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  providers: [UsersService, UserRepository],
  exports: [UsersService],
})
export class UsersModule {}
