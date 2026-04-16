import { ApiProperty } from '@nestjs/swagger';
import { IsISO8601, IsInt, IsString, Min } from 'class-validator';

export class TrackVoteResultDto {
  @ApiProperty({ example: 'event-123' })
  @IsString()
  eventId!: string;

  @ApiProperty({ example: 'track-456' })
  @IsString()
  trackId!: string;

  @ApiProperty({ example: 3 })
  @IsInt()
  @Min(0)
  upVotes!: number;

  @ApiProperty({ example: 1 })
  @IsInt()
  @Min(0)
  downVotes!: number;

  @ApiProperty({ example: 2 })
  @IsInt()
  score!: number;

  @ApiProperty({ example: '2026-04-15T10:00:00.000Z' })
  @IsISO8601()
  updatedAt!: string;
}
