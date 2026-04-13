import {
  IsEmail,
  IsString,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class RegisterDto {
  @ApiProperty({ example: 'user@example.com' })
  @IsEmail()
  email!: string;

  @ApiProperty({
    example: 'cool_musician',
    minLength: 3,
    maxLength: 30,
    description: 'Alphanumeric and underscores only',
  })
  @IsString()
  @MinLength(3)
  @MaxLength(30)
  @Matches(/^[a-zA-Z0-9_]+$/, {
    message: 'username must contain only letters, numbers, and underscores',
  })
  username!: string;

  @ApiProperty({ example: 'Abdel@1234', minLength: 8 })
  @IsString()
  @MinLength(8)
  @Matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$/, {
    message: 'password must contain at least one lowercase letter, one uppercase letter, one number, and one special character',
  })
  password!: string;

  @ApiProperty({ description: 'Token received from /auth/verify-otp' })
  @IsString()
  emailVerificationToken!: string;
}
