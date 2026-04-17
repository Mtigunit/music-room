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
