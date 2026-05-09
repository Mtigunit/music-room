import { ApiProperty } from '@nestjs/swagger';
import { IsBoolean, IsString, IsUUID } from 'class-validator';

export class DelegationResponseDto {
  @ApiProperty({ example: '123e4567-e89b-12d3-a456-426614174000' })
  @IsUUID()
  delegationId!: string;

  @ApiProperty({ example: true })
  @IsBoolean()
  accept!: boolean;

   @ApiProperty({ description: 'ID of the event related to the delegation' })
    @IsUUID()
    eventId!: string;
}
