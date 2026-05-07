import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { NotificationType } from '@prisma/client';
import { NotificationPayloadDto } from './notification-payload.dto';

export class NotificationResponseDto {
  @ApiProperty()
  id!: string;

  @ApiProperty({ enum: NotificationType })
  type!: NotificationType;

  @ApiProperty()
  title!: string;

  @ApiPropertyOptional({ nullable: true })
  message!: string | null;

  @ApiProperty({ type: NotificationPayloadDto })
  payload!: NotificationPayloadDto;

  @ApiProperty()
  isRead!: boolean;

  @ApiProperty({ format: 'date-time' })
  createdAt!: string;

  @ApiPropertyOptional({ format: 'date-time', nullable: true })
  readAt!: string | null;
}
