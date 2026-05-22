import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsString,
  IsOptional,
  MaxLength,
  IsArray,
  IsEnum,
  IsBoolean,
  ValidateNested,
  IsDateString,
  ArrayMaxSize,
  ArrayUnique,
} from 'class-validator';
import { Tags } from '@prisma/client';

export enum UiTheme {
  LIGHT = 'LIGHT',
  DARK = 'DARK',
  SYSTEM = 'SYSTEM',
}

export class PublicInfoDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(150)
  shortBio?: string;
}

export class FriendInfoDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(255)
  location?: string;
}

export class PrivateInfoDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  dateOfBirth?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(255)
  physicalAddress?: string;
}

export class PreferencesDto {
  @ApiPropertyOptional({ enum: Tags, isArray: true })
  @IsOptional()
  @IsArray()
  @IsEnum(Tags, { each: true })
  @ArrayMaxSize(8)
  @ArrayUnique({ message: 'Tags must not contain duplicate values' })
  favoriteGenres?: Tags[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  autoAcceptInvites?: boolean;

  @ApiPropertyOptional({ enum: UiTheme })
  @IsOptional()
  @IsEnum(UiTheme)
  uiTheme?: UiTheme;
}

export class UpdateProfileDto {
  @ApiPropertyOptional({ type: PublicInfoDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => PublicInfoDto)
  publicInfo?: PublicInfoDto;

  @ApiPropertyOptional({ type: FriendInfoDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => FriendInfoDto)
  friendInfo?: FriendInfoDto;

  @ApiPropertyOptional({ type: PrivateInfoDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => PrivateInfoDto)
  privateInfo?: PrivateInfoDto;

  @ApiPropertyOptional({ type: PreferencesDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => PreferencesDto)
  preferences?: PreferencesDto;
}
