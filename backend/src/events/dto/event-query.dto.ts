import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsEnum, IsString, MaxLength } from 'class-validator';
import { Transform } from 'class-transformer';
import { EventStatus, Tags } from '@prisma/client';
import { PaginationDto } from '../../common/dto/pagination.dto';

export class EventQueryDto extends PaginationDto {
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

  @ApiPropertyOptional({ description: 'Search term for name or description' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  search?: string;
}
