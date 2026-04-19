import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsString,
  IsEnum,
  IsArray,
  ArrayMinSize,
  ArrayMaxSize,
  IsOptional,
  IsNumber,
  ValidateNested,
  IsUUID,
  IsDateString,
  IsBoolean,
} from 'class-validator';
import { Transform, Type } from 'class-transformer';
import { EventVisibility, PolicyType, Prisma } from '@prisma/client';
import { AppendedTrackDto } from './append-tracks.dto';

export enum Tags {
  TEST1 = 'TEST1',
  TEST2 = 'TEST2',
  TEST3 = 'TEST3',
}

export class GeofenceConfigDto {
  [key: string]: Prisma.InputJsonValue | undefined;

  @ApiProperty()
  @IsNumber()
  distance: number;
}

export class TimeWindowConfigDto {
  [key: string]: Prisma.InputJsonValue | undefined;

  @ApiProperty()
  @IsDateString()
  startDate: string;

  @ApiProperty()
  @IsDateString()
  endDate: string;
}

export class LicensePolicyDto {
  @ApiProperty({ enum: PolicyType })
  @IsEnum(PolicyType)
  policyType: PolicyType;

  @ApiProperty({
    description: 'Configuration matching the policyType',
  })
  @ValidateNested()
  @Type((opts) =>
    opts?.object?.policyType === PolicyType.GEOFENCE
      ? GeofenceConfigDto
      : typeof opts?.object?.policyType === 'string' &&
          opts.object.policyType === PolicyType.TIME_WINDOW
        ? TimeWindowConfigDto
        : Object,
  )
  config: GeofenceConfigDto | TimeWindowConfigDto;
}

export class CreateEventDto {
  @ApiProperty()
  @IsString()
  name: string;

  @ApiProperty({ enum: Tags, isArray: true, minItems: 1, maxItems: 3 })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(3)
  @IsEnum(Tags, { each: true })
  @Transform(({ value }) => {
    // Handle JSON string array e.g. '["rock", "pop"]' from FormData
    if (
      typeof value === 'string' &&
      value.startsWith('[') &&
      value.endsWith(']')
    ) {
      try {
        return JSON.parse(value) as string[];
      } catch {
        return value;
      }
    }
    return Array.isArray(value) ? (value as string[]) : [value as string];
  })
  tags: string[];

  @ApiProperty({ enum: EventVisibility })
  // @IsIn(Object.values(EventVisibility))
  @IsEnum(EventVisibility)
  visibility: EventVisibility;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  @Transform(({ value }) => {
    if (value === 'true') return true;
    if (value === 'false') return false;
    return value as boolean;
  })
  invitingOnly?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional({ type: 'string', format: 'binary' })
  @IsOptional()
  coverImage?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  @Transform(({ value }) => {
    if (typeof value === 'string') {
      return parseFloat(value.replace(',', '.'));
    }
    return typeof value === 'number' ? value : Number(value);
  })
  locationLat?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  @Transform(({ value }) => {
    if (typeof value === 'string') {
      return parseFloat(value.replace(',', '.'));
    }
    return typeof value === 'number' ? value : Number(value);
  })
  locationLng?: number;

  @ApiPropertyOptional({ type: [LicensePolicyDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => LicensePolicyDto)
  @Transform(({ value }) => {
    if (
      typeof value === 'string' &&
      value.trim().startsWith('[') &&
      value.trim().endsWith(']')
    ) {
      try {
        return JSON.parse(value) as LicensePolicyDto[];
      } catch {
        return value;
      }
    }
    return Array.isArray(value)
      ? (value as LicensePolicyDto[])
      : [value as LicensePolicyDto];
  })
  policies?: LicensePolicyDto[];

  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @IsUUID('all', { each: true })
  @Transform(({ value }) => {
    if (
      typeof value === 'string' &&
      value.startsWith('[') &&
      value.endsWith(']')
    ) {
      try {
        return JSON.parse(value) as string[];
      } catch {
        return value;
      }
    }
    return Array.isArray(value) ? (value as string[]) : [value as string];
  })
  playlistIds?: string[];

  @ApiPropertyOptional({ type: [AppendedTrackDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => AppendedTrackDto)
  @Transform(({ value }) => {
    if (
      typeof value === 'string' &&
      value.startsWith('[') &&
      value.endsWith(']')
    ) {
      try {
        return JSON.parse(value) as AppendedTrackDto[];
      } catch {
        return value;
      }
    }
    return Array.isArray(value)
      ? (value as AppendedTrackDto[])
      : [value as AppendedTrackDto];
  })
  tracks?: AppendedTrackDto[];
}
