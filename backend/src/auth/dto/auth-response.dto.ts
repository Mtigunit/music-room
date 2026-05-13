import { ApiProperty } from '@nestjs/swagger';

export class AuthUserDto {
  @ApiProperty({ description: 'The unique identifier of the user' })
  id: string;

  @ApiProperty({ description: 'The email address of the user' })
  email: string;

  @ApiProperty({ description: 'The username of the user' })
  username: string;
}

export class AuthResponseDto {
  @ApiProperty({ description: 'JWT access token' })
  access_token: string;

  @ApiProperty({
    description: 'The authenticated user details',
    type: AuthUserDto,
  })
  user: AuthUserDto;

  @ApiProperty({
    description: 'Whether this is a newly created user account',
    example: true,
  })
  isNewUser: boolean;
}
