import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsString, IsOptional, IsIP } from 'class-validator';

export class ClientMetaDto {
  @ApiProperty({
    description: 'Client platform (e.g., ios, android, web)',
    default: 'unknown',
  })
  @IsString()
  @IsOptional()
  platform: string = 'unknown';

  @ApiProperty({
    description: 'Client device model (e.g., iPhone 13, Chrome)',
    default: 'unknown',
  })
  @IsString()
  @IsOptional()
  deviceModel: string = 'unknown';

  @ApiProperty({
    description: 'Client hardware device ID',
    default: 'unknown',
  })
  @IsString()
  @IsOptional()
  deviceId: string = 'unknown';

  @ApiProperty({
    description: 'Client app version (e.g., 1.0.0)',
    default: 'unknown',
  })
  @IsString()
  @IsOptional()
  appVersion: string = 'unknown';

  @ApiPropertyOptional({
    description: 'Client IP address',
  })
  @IsOptional()
  @IsIP()
  ipAddress?: string;
}
