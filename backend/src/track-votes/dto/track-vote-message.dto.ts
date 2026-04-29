import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsIn,
  IsString,
  MinLength,
  IsOptional,
  IsNumber,
} from 'class-validator';

export class TrackVoteMessageDto {
  @ApiProperty({ example: 'room-123' })
  @IsString()
  @MinLength(1)
  eventId!: string;

  @ApiProperty({ example: 'track-456' })
  @IsString()
  @MinLength(1)
  trackId!: string;

  @ApiProperty({ enum: ['up', 'down', 'none'], example: 'up' })
  @IsIn(['up', 'down', 'none'])
  vote!: 'up' | 'down' | 'none';

  @ApiPropertyOptional({ example: 40.7128 })
  @IsOptional()
  @IsNumber()
  locationLat?: number;

  @ApiPropertyOptional({ example: -74.006 })
  @IsOptional()
  @IsNumber()
  locationLng?: number;
}
