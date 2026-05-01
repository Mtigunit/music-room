import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsNotEmpty } from 'class-validator';

export class PlaybackPlayDto {
  @ApiProperty({ description: 'ID of the event to play' })
  @IsString()
  @IsNotEmpty()
  eventId!: string;
}
