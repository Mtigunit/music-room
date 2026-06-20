import { ApiProperty } from '@nestjs/swagger';
import { IsUUID, IsNotEmpty } from 'class-validator';

export class EventRoomDto {
  @ApiProperty()
  @IsUUID('4', { message: 'eventId must be a valid UUID' })
  @IsNotEmpty()
  eventId!: string;
}
