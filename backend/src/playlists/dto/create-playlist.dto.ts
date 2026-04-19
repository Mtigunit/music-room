import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { PlaylistEditLicense, PlaylistVisibility } from '@prisma/client';
import { PlaylistTag } from '../enums/playlist.enum';

export class CreatePlaylistDto {
  @ApiProperty({
    example: 'Weekend Vibes',
    maxLength: 50,
    description: 'The name of the playlist',
  })
  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  name: string;

  @ApiProperty({
    enum: PlaylistVisibility,
    example: PlaylistVisibility.PUBLIC,
    description: 'Playlist visibility',
  })
  @IsEnum(PlaylistVisibility)
  @IsNotEmpty()
  visibility: PlaylistVisibility;

  @ApiProperty({
    enum: PlaylistEditLicense,
    example: PlaylistEditLicense.OPEN,
    description: 'Who can edit this playlist',
  })
  @IsEnum(PlaylistEditLicense)
  @IsNotEmpty()
  editLicense: PlaylistEditLicense;

  @ApiPropertyOptional({
    example: 'Perfect tunes for the weekend getaway.',
    maxLength: 255,
  })
  @IsString()
  @IsOptional()
  @MaxLength(255)
  description?: string;

  @ApiPropertyOptional({
    example: [PlaylistTag.CHILL, PlaylistTag.ACOUSTIC],
    maxItems: 5,
    description: 'Array of genre tags',
    enum: PlaylistTag,
    isArray: true,
  })
  @IsArray()
  @IsEnum(PlaylistTag, { each: true })
  @IsOptional()
  @ArrayMaxSize(5)
  tags?: PlaylistTag[];
}
