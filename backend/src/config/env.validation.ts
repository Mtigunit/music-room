import { plainToInstance } from 'class-transformer';
import {
  IsEnum,
  IsNotEmpty,
  IsNumber,
  IsString,
  Max,
  Min,
  validateSync,
} from 'class-validator';

enum Environment {
  Development = 'development',
  Production = 'production',
  Test = 'test',
}

export class EnvironmentVariables {
  @IsEnum(Environment)
  NODE_ENV: Environment = Environment.Development;

  @IsString()
  @IsNotEmpty()
  DATABASE_URL!: string;

  @IsNumber()
  @Min(1)
  @Max(65535)
  API_PORT: number = 3000;

  @IsString()
  @IsNotEmpty()
  POSTGRES_HOST!: string;

  @IsNumber()
  @Min(1)
  @Max(65535)
  POSTGRES_PORT: number = 5432;

  @IsString()
  @IsNotEmpty()
  POSTGRES_USER!: string;

  @IsString()
  @IsNotEmpty()
  POSTGRES_PASSWORD!: string;

  @IsString()
  @IsNotEmpty()
  POSTGRES_DB!: string;

  @IsString()
  @IsNotEmpty()
  REDIS_HOST!: string;

  @IsNumber()
  @Min(1)
  @Max(65535)
  REDIS_PORT: number = 6379;

  @IsString()
  @IsNotEmpty()
  JWT_SECRET!: string;

  @IsString()
  @IsNotEmpty()
  GOOGLE_CLIENT_ID!: string;

  @IsString()
  @IsNotEmpty()
  YOUTUBE_API_KEY!: string;

  @IsNumber()
  @Min(1000)
  DB_TRANSACTION_TIMEOUT: number = 10000;

  @IsNumber()
  @Min(1000)
  DB_HEAVY_TRANSACTION_TIMEOUT: number = 20000;

  @IsNumber()
  RATE_LIMIT_DEFAULT_TTL_MS: number = 60000;

  @IsNumber()
  RATE_LIMIT_DEFAULT_LIMIT: number = 100;

  @IsNumber()
  RATE_LIMIT_WS_TTL_MS: number = 60000;

  @IsNumber()
  RATE_LIMIT_WS_LIMIT: number = 30;

  @IsNumber()
  RATE_LIMIT_AUTH_TTL_MS: number = 60000;

  @IsNumber()
  RATE_LIMIT_AUTH_LIMIT: number = 10;

  @IsNumber()
  RATE_LIMIT_SEARCH_TTL_MS: number = 60000;

  @IsNumber()
  RATE_LIMIT_SEARCH_LIMIT: number = 30;
}

export function validate(config: Record<string, unknown>) {
  const validatedConfig = plainToInstance(EnvironmentVariables, config, {
    enableImplicitConversion: true,
  });

  const errors = validateSync(validatedConfig, {
    skipMissingProperties: false,
  });

  if (errors.length > 0) {
    throw new Error(
      `\nEnvironment validation failed:\n${errors.map((e) => `  - ${Object.values(e.constraints ?? {}).join(', ')}`).join('\n')}\n`,
    );
  }

  return validatedConfig;
}
