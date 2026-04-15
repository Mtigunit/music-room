import { ApiProperty } from '@nestjs/swagger';
import { IsIn, IsString, MinLength } from 'class-validator';

export class TrackVoteMessageDto {
  @ApiProperty({ example: 'room-123' })
  @IsString()
  @MinLength(1)
  roomId!: string;

  @ApiProperty({ example: 'track-456' })
  @IsString()
  @MinLength(1)
  trackId!: string;

  @ApiProperty({ enum: ['up', 'down'], example: 'up' })
  @IsIn(['up', 'down'])
  vote!: 'up' | 'down';
}
