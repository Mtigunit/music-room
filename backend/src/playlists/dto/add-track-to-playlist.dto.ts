import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString } from 'class-validator';

export class AddTrackToPlaylistDto {
  @ApiProperty({
    example: 'dQw4w9WgXcQ',
    description:
      'The unique ID of the track from the provider (e.g. YouTube video ID)',
  })
  @IsString()
  @IsNotEmpty()
  providerTrackId!: string;
}
