import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsUUID } from 'class-validator';

export class PlaybackPauseDto {
  @ApiProperty({ description: 'ID of the event to pause' })
  @IsUUID('4')
  @IsNotEmpty()
  eventId!: string;
}
