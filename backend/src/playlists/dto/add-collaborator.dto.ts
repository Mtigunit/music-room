import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsUUID } from 'class-validator';

export class AddCollaboratorDto {
  @ApiProperty({
    description: 'The UUID of the user to be added as a collaborator',
    example: '123e4567-e89b-12d3-a456-426614174000',
  })
  @IsUUID()
  @IsNotEmpty()
  targetUserId: string;
}
