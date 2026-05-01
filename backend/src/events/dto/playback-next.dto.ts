import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty, IsOptional } from 'class-validator';

export class PlaybackNextDto {
  @ApiProperty({ description: 'ID of the event to skip track' })
  @IsString()
  @IsNotEmpty()
  eventId!: string;

  @ApiProperty({
    description: 'Current track ID for staleness check',
    nullable: true,
  })
  @IsOptional()
  @IsString()
  trackId?: string | null;
}
