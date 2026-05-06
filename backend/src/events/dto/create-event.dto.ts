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
import { Transform, Type, plainToInstance } from 'class-transformer';
import { Visibility, PolicyType, Prisma, Tags } from '@prisma/client';
import {
  registerDecorator,
  ValidationOptions,
  ValidationArguments,
} from 'class-validator';

export function IsValidPoliciesArray(validationOptions?: ValidationOptions) {
  return function (object: object, propertyName: string) {
    registerDecorator({
      name: 'isValidPoliciesArray',
      target: object.constructor,
      propertyName,
      options: validationOptions,
      validator: {
        validate(value: unknown) {
          if (value === undefined || value === null) return true;
          if (!Array.isArray(value)) return false;
          if (value.length === 0 || value.length > 2) return false;

          const types = value.map((p: LicensePolicyDto) => p.policyType);

          // No duplicates allowed
          const uniqueTypes = new Set(types);
          if (uniqueTypes.size !== types.length) return false;

          // Each policyType must be a valid PolicyType
          const validTypes = Object.values(PolicyType);
          return types.every((t) => validTypes.includes(t));
        },
        defaultMessage(args: ValidationArguments) {
          const value = args.value as unknown;
          if (!Array.isArray(value)) {
            return `${args.property} must be an array`;
          }
          if (value.length === 0 || value.length > 2) {
            return `${args.property} must contain 1 or 2 policies, got ${value.length}`;
          }
          return `${args.property} must contain unique valid policy types (GEOFENCE, TIME_WINDOW)`;
        },
      },
    });
  };
}

export function IsStartBeforeEnd(validationOptions?: ValidationOptions) {
  return function (object: object, propertyName: string) {
    registerDecorator({
      name: 'isStartBeforeEnd',
      target: object.constructor,
      propertyName,
      options: validationOptions,
      validator: {
        validate(value: unknown, args: ValidationArguments) {
          const obj = args.object as TimeWindowConfigDto;
          if (!value || !obj.endDate) return true;
          const start = new Date(value as string);
          const end = new Date(obj.endDate);
          if (isNaN(start.getTime()) || isNaN(end.getTime())) return true;
          return start < end;
        },
        defaultMessage() {
          return `startDate must be before endDate`;
        },
      },
    });
  };
}

const normalizeProviderTrackIds = (value: unknown): string[] | undefined => {
  if (value === undefined || value === null || value === '') return undefined;

  const extractProviderTrackId = (entry: unknown): string => {
    if (typeof entry === 'string') return entry;
    if (entry && typeof entry === 'object' && 'providerTrackId' in entry) {
      const id = (entry as { providerTrackId?: unknown }).providerTrackId;
      return typeof id === 'string' ? id : '';
    }
    return typeof entry === 'string' ? entry : '';
  };

  const toArray = (entries: unknown[]): string[] =>
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
        return [value];
      }
    }
    return [value];
  }

  if (Array.isArray(value)) {
    return toArray(value);
  }

  return [extractProviderTrackId(value)];
};

// Shared helper — parses a JSON array string and returns the parsed array,
// or a sentinel string that will fail @IsArray() with a clear message
const parseJsonArrayField = <T>(
  value: unknown,
  fieldName: string,
): T[] | string | undefined => {
  if (value === undefined || value === null || value === '') return undefined;
  if (Array.isArray(value)) return value as T[];
  if (
    typeof value === 'string' &&
    value.trim().startsWith('[') &&
    value.trim().endsWith(']')
  ) {
    try {
      return JSON.parse(value) as T[];
    } catch {
      return `INVALID_JSON_ARRAY:${fieldName}`;
    }
  }
  // Single scalar value — wrap in array
  return [value as T];
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
  @IsStartBeforeEnd()
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
  @Transform(({ value }): Tags[] | string | undefined =>
    parseJsonArrayField<Tags>(value, 'tags'),
  )
  tags!: Tags[];

  @ApiProperty({ enum: Visibility })
  @IsEnum(Visibility)
  visibility!: Visibility;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(({ value }): boolean => {
    if (value === 'true' || value === true || value === '1' || value === 1)
      return true;
    if (value === 'false' || value === false || value === '0' || value === 0)
      return false;
    return value;
  })
  @IsBoolean()
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
  @Transform(({ obj, key }): number | undefined => {
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
  @Transform(({ obj, key }): number | undefined => {
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
  @IsValidPoliciesArray()
  @Type(() => LicensePolicyDto)
  @Transform(({ value }): LicensePolicyDto[] | string | undefined => {
    if (value === undefined || value === null || value === '') return undefined;

    let parsed: unknown = value;

    if (
      typeof value === 'string' &&
      value.trim().startsWith('[') &&
      value.trim().endsWith(']')
    ) {
      try {
        parsed = JSON.parse(value) as unknown;
      } catch {
        return 'INVALID_JSON_ARRAY:policies';
      }
    }

    const arr = Array.isArray(parsed) ? parsed : [parsed];

    return (arr as Record<string, unknown>[]).map((item) => {
      const policy = new LicensePolicyDto();
      policy.policyType = item.policyType as PolicyType;

      if (item.policyType === PolicyType.GEOFENCE) {
        policy.config = plainToInstance(GeofenceConfigDto, item.config);
      } else if (item.policyType === PolicyType.TIME_WINDOW) {
        policy.config = plainToInstance(TimeWindowConfigDto, item.config);
      } else {
        policy.config = item.config as GeofenceConfigDto;
      }

      return policy;
    });
  })
  policies?: LicensePolicyDto[];

  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @IsUUID('all', { each: true })
  @Transform(({ value }): string[] | string | undefined =>
    parseJsonArrayField<string>(value, 'playlistIds'),
  )
  playlistIds?: string[];

  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @Transform(({ value }): string[] | undefined =>
    normalizeProviderTrackIds(value),
  )
  tracks?: string[];

  @ApiProperty()
  @IsDate()
  @Transform(({ value }): unknown => {
    if (!value) return value;
    const date = new Date(value as string);
    return isNaN(date.getTime()) ? value : date;
  })
  startDate!: Date;
}
