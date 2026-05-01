import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNumber, IsOptional, IsISO8601 } from 'class-validator';

export class PlaybackStatusDto {
  @ApiProperty({ description: 'Playback status (PLAYING or PAUSED)' })
  @IsString()
  status!: string;

  @ApiProperty({ description: 'Current track ID', nullable: true })
  @IsOptional()
  @IsString()
  currentTrackId?: string | null;

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
