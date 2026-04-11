import { Injectable } from '@nestjs/common';
import { PrismaService } from './prisma/prisma.service';

@Injectable()
export class AppService {
  constructor(private readonly prisma: PrismaService) {}

  getHello(): string {
    return 'Hello World!';
  }

  async testDbQuery() {
    const result = await this.prisma.$queryRaw<
      { ok: number }[]
    >`SELECT 1 AS ok`;
    return {
      db: 'ok',
      result: result[0]?.ok ?? 0,
    };
  }
}
