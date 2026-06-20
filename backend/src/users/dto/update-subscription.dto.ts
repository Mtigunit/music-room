import { ApiProperty } from '@nestjs/swagger';
import { SubscriptionTier } from '@prisma/client';
import { IsEnum } from 'class-validator';

export class UpdateSubscriptionDto {
  @ApiProperty({
    description: 'Target subscription tier',
    enum: SubscriptionTier,
    example: SubscriptionTier.PREMIUM,
  })
  @IsEnum(SubscriptionTier)
  subscriptionTier!: SubscriptionTier;
}
