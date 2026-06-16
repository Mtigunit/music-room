import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsUUID } from 'class-validator';

export class PlaybackNextDto {
  @ApiProperty({ description: 'ID of the event to skip track' })
  @IsUUID('4')
  @IsNotEmpty()
  eventId!: string;

  @ApiProperty({
    description: 'Current track ID for staleness check',
    nullable: true,
  })
  @IsOptional()
  @IsUUID('4')
  trackId?: string | null;
}
