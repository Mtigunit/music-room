import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsString,
  IsEnum,
  IsArray,
  ArrayMinSize,
  ArrayMaxSize,
  ArrayUnique,
  IsOptional,
  IsNumber,
  ValidateNested,
  IsUUID,
  IsDateString,
  IsBoolean,
  IsDate,
} from 'class-validator';
import { Transform, Type } from 'class-transformer';
import { Visibility, PolicyType, Prisma, Tags } from '@prisma/client';

const normalizeProviderTrackIds = (value: unknown): unknown => {
  if (value === undefined || value === null || value === '') return undefined;

  const extractProviderTrackId = (entry: unknown): unknown => {
    if (typeof entry === 'string') return entry;
    if (entry && typeof entry === 'object' && 'providerTrackId' in entry) {
      return (entry as { providerTrackId?: unknown }).providerTrackId;
    }
    return entry;
  };

  const toArray = (entries: unknown[]): unknown[] =>
    entries.map((entry) => extractProviderTrackId(entry));

  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      try {
        const parsed = JSON.parse(trimmed) as unknown;
        return Array.isArray(parsed)
          ? toArray(parsed)
          : [extractProviderTrackId(parsed)];
      } catch {
        return value;
      }
    }
    return [value];
  }

  if (Array.isArray(value)) {
    return toArray(value);
  }

  return [extractProviderTrackId(value)];
};

export class GeofenceConfigDto {
  [key: string]: Prisma.InputJsonValue | undefined;

  @ApiProperty()
  @IsNumber()
  distance!: number;
}

export class TimeWindowConfigDto {
  [key: string]: Prisma.InputJsonValue | undefined;

  @ApiProperty()
  @IsDateString()
  startDate!: string;

  @ApiProperty()
  @IsDateString()
  endDate!: string;
}

export class LicensePolicyDto {
  @ApiProperty({ enum: PolicyType })
  @IsEnum(PolicyType)
  policyType!: PolicyType;

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
  config!: GeofenceConfigDto | TimeWindowConfigDto;
}

export class CreateEventDto {
  @ApiProperty()
  @IsString()
  name!: string;

  @ApiProperty({ enum: Tags, isArray: true, minItems: 1, maxItems: 3 })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(3)
  @IsEnum(Tags, { each: true })
  @ArrayUnique({ message: 'Tags must not contain duplicate values' })
  @Transform(({ value }) => {
    if (value === undefined || value === null || value === '') return undefined;
    // Handle JSON string array e.g. '["rock", "pop"]' from FormData
    if (
      typeof value === 'string' &&
      value.trim().startsWith('[') &&
      value.trim().endsWith(']')
    ) {
      try {
        return JSON.parse(value) as Tags[];
      } catch {
        return value;
      }
    }
    return Array.isArray(value) ? (value as Tags[]) : [value as Tags];
  })
  tags!: Tags[];

  @ApiProperty({ enum: Visibility })
  @IsEnum(Visibility)
  visibility!: Visibility;

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
  @Transform(({ obj, key }) => {
    const value = (obj as Record<string, unknown>)?.[key];
    if (
      value === '' ||
      value === null ||
      value === undefined ||
      value === 'null' ||
      value === 'undefined'
    )
      return undefined;
    if (typeof value === 'string') {
      const parsed = parseFloat(value.replace(',', '.'));
      return isNaN(parsed) ? undefined : parsed;
    }
    const num = Number(value);
    return isNaN(num) ? undefined : num;
  })
  locationLat?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  @Transform(({ obj, key }) => {
    const value = (obj as Record<string, unknown>)?.[key];
    if (
      value === '' ||
      value === null ||
      value === undefined ||
      value === 'null' ||
      value === 'undefined'
    )
      return undefined;
    if (typeof value === 'string') {
      const parsed = parseFloat(value.replace(',', '.'));
      return isNaN(parsed) ? undefined : parsed;
    }
    const num = Number(value);
    return isNaN(num) ? undefined : num;
  })
  locationLng?: number;

  @ApiPropertyOptional({ type: [LicensePolicyDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => LicensePolicyDto)
  @Transform(({ value }) => {
    if (value === undefined || value === null || value === '') return undefined;
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
    if (value === undefined || value === null || value === '') return undefined;
    if (
      typeof value === 'string' &&
      value.trim().startsWith('[') &&
      value.trim().endsWith(']')
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

  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @Transform(({ value }) => normalizeProviderTrackIds(value))
  tracks?: string[];

  @ApiProperty()
  @IsDate()
  startDate!: Date;
}
