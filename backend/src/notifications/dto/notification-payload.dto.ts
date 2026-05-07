import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsObject, IsOptional, IsString } from 'class-validator';

export enum NotificationPayloadType {
  USER = 'USER',
  EVENT = 'EVENT',
}

export class NotificationPayloadDto {
  @ApiProperty({ enum: NotificationPayloadType })
  @IsEnum(NotificationPayloadType)
  payloadType!: NotificationPayloadType;

  @ApiProperty({ description: 'The primary identifier for deep linking.' })
  @IsString()
  id!: string;

  @ApiPropertyOptional({ description: 'Optional metadata for client routing.' })
  @IsOptional()
  @IsObject()
  meta?: Record<string, unknown>;
}

export type NotificationPayload = NotificationPayloadDto;
