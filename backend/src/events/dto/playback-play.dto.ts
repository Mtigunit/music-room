import { IsNotEmpty, IsString, IsUUID } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class PlaybackPlayDto {
  @ApiProperty({ description: 'ID of the event to play' })
  @IsString()
  @IsNotEmpty()
  @IsUUID()
  eventId!: string;
}
