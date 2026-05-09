import { ApiProperty } from '@nestjs/swagger';
import {
  IsString,
  IsNumber,
  IsOptional,
  IsISO8601,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

class CurrentTrackDto {
  @ApiProperty({ description: 'Track UUID' })
  @IsString()
  id!: string;

  @ApiProperty({ description: 'Provider track ID' })
  @IsString()
  providerTrackId!: string;

  @ApiProperty({ description: 'Track title' })
  @IsString()
  title!: string;

  @ApiProperty({ description: 'Track artist', nullable: true })
  @IsOptional()
  @IsString()
  artist?: string | null;

  @ApiProperty({ description: 'Track duration in milliseconds' })
  @IsNumber()
  durationMs!: number;

  @ApiProperty({ description: 'Track thumbnail URL', nullable: true })
  @IsOptional()
  @IsString()
  thumbnailUrl?: string | null;
}

export class PlaybackStatusDto {
  @ApiProperty({ description: 'Playback status (PLAYING or PAUSED)' })
  @IsString()
  status!: string;

  @ApiProperty({
    description: 'Current track details',
    nullable: true,
    type: CurrentTrackDto,
  })
  @IsOptional()
  @ValidateNested()
  @Type(() => CurrentTrackDto)
  currentTrack?: CurrentTrackDto | null;

  @ApiProperty({
    description: 'When the track started playing',
    nullable: true,
  })
  @IsOptional()
  @IsISO8601()
  currentTrackStartedAt?: string | null;

  @ApiProperty({ description: 'Paused position in ms', nullable: true })
  @IsOptional()
  @IsNumber()
  pausedPlaybackPositionMs?: number | null;
}
