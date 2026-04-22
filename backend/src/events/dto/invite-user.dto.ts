import { ApiProperty } from '@nestjs/swagger';
import { IsUUID } from 'class-validator';

export class InviteUserDto {
  @ApiProperty({ description: 'The UUID of the user to invite' })
  @IsUUID()
  userId!: string;
}
