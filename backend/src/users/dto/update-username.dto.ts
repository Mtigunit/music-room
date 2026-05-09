import { ApiProperty } from '@nestjs/swagger';
import { IsString, Length, Matches } from 'class-validator';

export class UpdateUsernameDto {
  @ApiProperty({
    description: 'The new username for the user',
    minLength: 3,
    maxLength: 30,
    example: 'new_username_123',
  })
  @IsString()
  @Length(3, 30)
  @Matches(/^[a-zA-Z0-9_]+$/, {
    message: 'Username can only contain letters, numbers, and underscores',
  })
  username: string;
}
