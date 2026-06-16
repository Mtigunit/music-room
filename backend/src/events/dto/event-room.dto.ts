import { IsNotEmpty, IsString, IsUUID } from 'class-validator';

export class EventRoomDto {
  @IsString()
  @IsNotEmpty()
  @IsUUID()
  eventId!: string;
}
