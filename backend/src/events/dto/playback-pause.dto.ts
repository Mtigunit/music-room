import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty } from 'class-validator';

export class PlaybackPauseDto {
  @ApiProperty({ description: 'ID of the event to pause' })
  @IsString()
  @IsNotEmpty()
  eventId!: string;
}
