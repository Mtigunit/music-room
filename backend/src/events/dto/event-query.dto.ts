import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsEnum, IsString, IsInt, Min, Max } from 'class-validator';
import { Transform, Type } from 'class-transformer';
import { EventStatus, Tags } from '@prisma/client';

export class EventQueryDto {
  @ApiPropertyOptional({
    enum: EventStatus,
    description: 'Filter events by status',
  })
  @IsOptional()
  @IsEnum(EventStatus)
  status?: EventStatus;

  @ApiPropertyOptional({
    enum: Tags,
    isArray: true,
    description: 'Filter events by tags',
  })
  @IsOptional()
  @Transform(({ value }: { value: Tags[] }) =>
    Array.isArray(value) ? value : [value],
  )
  @IsEnum(Tags, { each: true })
  tags?: Tags[];

  @ApiPropertyOptional({ default: 1, description: 'Page number' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @ApiPropertyOptional({
    default: 10,
    description: 'Number of items per page',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number = 10;

  @ApiPropertyOptional({ description: 'Search term for name or description' })
  @IsOptional()
  @IsString()
  search?: string;
}
