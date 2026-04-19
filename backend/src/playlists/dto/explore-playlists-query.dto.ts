import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsOptional, IsString } from 'class-validator';
import { Tags } from '@prisma/client';
import { PaginationDto } from '../../common/dto/pagination.dto';

export class ExplorePlaylistsQueryDto extends PaginationDto {
  @ApiPropertyOptional({
    description: 'Search by playlist name or description',
    example: 'chill',
  })
  @IsOptional()
  @IsString()
  q?: string;

  @ApiPropertyOptional({
    description: 'Filter by playlist tag',
    enum: Tags,
    example: Tags.CHILL,
  })
  @IsOptional()
  @IsEnum(Tags)
  tag?: Tags;
}
