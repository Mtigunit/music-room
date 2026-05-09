import { Module } from '@nestjs/common';
import { DelegationsController } from './delegations.controller';
import { DelegationsService } from './delegations.service';
import { DelegationsRepository } from './delegations.repository';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [DelegationsController],
  providers: [DelegationsService, DelegationsRepository],
  exports: [DelegationsService],
})
export class DelegationsModule {}
