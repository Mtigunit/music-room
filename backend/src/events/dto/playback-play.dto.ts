import { IsNotEmpty, IsString, IsUUID } from 'class-validator';

export class PlaybackPlayDto {
  @IsString()
  @IsNotEmpty()
  @IsUUID()
  eventId!: string;
}
