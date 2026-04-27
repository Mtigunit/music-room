import { IsString, IsOptional, IsIP } from 'class-validator';

export class ClientMetaDto {
  @IsString()
  @IsOptional()
  platform: string = 'unknown';

  @IsString()
  @IsOptional()
  deviceModel: string = 'unknown';

  @IsString()
  @IsOptional()
  appVersion: string = 'unknown';

  @IsOptional()
  @IsIP()
  ipAddress?: string;
}
