import { Injectable } from '@nestjs/common';
import { PrismaService } from './prisma/prisma.service';

@Injectable()
export class AppRepository {
  constructor(private readonly prisma: PrismaService) {}

  // Example DB query method
  // async testDbQuery(): Promise<{ db: string; result: number }> {
  //   const result = await this.prisma.$queryRaw<{ ok: number }[]>`SELECT 1 AS ok`;
  //   return {
  //     db: 'ok',
  //     result: result[0]?.ok ?? 0,
  //   };
  // }
}
