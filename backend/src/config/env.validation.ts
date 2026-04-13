import { plainToInstance } from 'class-transformer';
import {
  IsEnum,
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
  DATABASE_URL!: string;

  @IsNumber()
  @Min(1)
  @Max(65535)
  API_PORT: number = 3000;

  @IsString()
  POSTGRES_HOST!: string;

  @IsNumber()
  @Min(1)
  @Max(65535)
  POSTGRES_PORT: number = 5432;

  @IsString()
  POSTGRES_USER!: string;

  @IsString()
  POSTGRES_PASSWORD!: string;

  @IsString()
  POSTGRES_DB!: string;

  @IsString()
  REDIS_HOST!: string;

  @IsNumber()
  @Min(1)
  @Max(65535)
  REDIS_PORT: number = 6379;

  @IsString()
  JWT_SECRET!: string;
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
