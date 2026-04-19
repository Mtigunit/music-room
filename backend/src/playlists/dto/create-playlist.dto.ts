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
import { PlaylistEditLicense, Visibility, Tags } from '@prisma/client';

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
    enum: Visibility,
    example: Visibility.PUBLIC,
    description: 'Playlist visibility',
  })
  @IsEnum(Visibility)
  @IsNotEmpty()
  visibility: Visibility;

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
    example: [Tags.CHILL, Tags.ACOUSTIC],
    maxItems: 5,
    description: 'Array of genre tags',
    enum: Tags,
    isArray: true,
  })
  @IsArray()
  @IsEnum(Tags, { each: true })
  @IsOptional()
  @ArrayMaxSize(5)
  tags?: Tags[];
}
