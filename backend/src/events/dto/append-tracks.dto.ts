import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsArray,
  ArrayMinSize,
  ValidateNested,
  IsString,
  IsInt,
  IsOptional,
} from 'class-validator';
import { Type } from 'class-transformer';

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

export class AppendTracksDto {
  @ApiProperty({ type: [AppendedTrackDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => AppendedTrackDto)
  tracks: AppendedTrackDto[];
}
