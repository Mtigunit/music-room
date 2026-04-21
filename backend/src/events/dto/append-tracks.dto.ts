import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsInt, IsOptional } from 'class-validator';

export class AppendedTrackDto {
  @ApiProperty()
  @IsString()
  providerTrackId: string;

  @ApiProperty()
  @IsString()
  title: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  artist?: string;

  @ApiProperty()
  @IsInt()
  durationMs: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  thumbnailUrl?: string;
}
