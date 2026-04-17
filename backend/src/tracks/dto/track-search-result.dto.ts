import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUrl,
  Min,
} from 'class-validator';

export class TrackSearchResultDto {
  @ApiProperty({
    example: 'dQw4w9WgXcQ',
    description: 'The YouTube video ID.',
  })
  @IsString()
  @IsNotEmpty()
  providerTrackId!: string;

  @ApiProperty({ example: 'Blinding Lights' })
  @IsString()
  @IsNotEmpty()
  title!: string;

  @ApiProperty({ example: 'The Weeknd' })
  @IsString()
  @IsNotEmpty()
  artist!: string;

  @ApiProperty({ example: 253000, description: 'Duration in milliseconds.' })
  @IsInt()
  @Min(0)
  durationMs!: number;

  @ApiPropertyOptional({
    example: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg',
  })
  @IsOptional()
  @IsUrl()
  thumbnailUrl?: string;
}
