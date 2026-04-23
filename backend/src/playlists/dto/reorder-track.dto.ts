import { ApiProperty } from '@nestjs/swagger';
import { IsISO8601, IsInt, Min } from 'class-validator';

export class ReorderTrackDto {
  @ApiProperty({
    description: 'The new 0-based position to move the track to',
    example: 0,
  })
  @IsInt()
  @Min(0)
  newPosition!: number;

  @ApiProperty({
    description:
      'The last known updatedAt timestamp of the playlist for Optimistic Concurrency Control',
    example: '2026-04-21T10:05:00.000Z',
  })
  @IsISO8601()
  baseUpdatedAt!: string;
}
