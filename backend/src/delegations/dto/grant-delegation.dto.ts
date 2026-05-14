import { IsNotEmpty, IsUUID } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class GrantDelegationDto {
  @ApiProperty({
    description: 'User ID of the friend to delegate control to',
    example: '550e8400-e29b-41d4-a716-446655440000',
  })
  @IsNotEmpty()
  @IsUUID()
  delegateeId!: string;
}
