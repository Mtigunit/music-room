import { ApiProperty } from '@nestjs/swagger';

export class AudioStreamResponseDto {
  @ApiProperty({
    description: 'The direct stream URL of the YouTube audio',
    example: 'https://rr5---sn-a5mlkn7d.googlevideo.com/...',
  })
  url: string;

  @ApiProperty({
    description: 'The title of the YouTube video',
    example: 'Rick Astley - Never Gonna Give You Up (Official Music Video)',
    required: false,
  })
  title?: string;

  @ApiProperty({
    description: 'The duration of the YouTube video in seconds',
    example: 212,
    required: false,
  })
  duration?: number;
}
