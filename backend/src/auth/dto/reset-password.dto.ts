import { ApiProperty } from '@nestjs/swagger';
import {
  IsEmail,
  IsNotEmpty,
  IsString,
  MinLength,
  Matches,
} from 'class-validator';

export class ResetPasswordDto {
  @ApiProperty({
    description: 'The email address of the account',
    example: 'user@example.com',
  })
  @IsEmail()
  @IsNotEmpty()
  email: string;

  @ApiProperty({
    description:
      'The JWT password reset proof token (returned from /verify-reset-otp)',
    example: 'eyJhbGciOiJIUzI1NiIs...',
  })
  @IsString()
  @IsNotEmpty()
  resetToken: string;

  @ApiProperty({
    description: 'The new password (must meet complexity requirements)',
    example: 'Abcd@1234',
    minLength: 8,
  })
  @IsString()
  @IsNotEmpty()
  @MinLength(8)
  @Matches(/(?=.*[a-z])/, {
    message: 'Password must contain a lowercase letter',
  })
  @Matches(/(?=.*[A-Z])/, {
    message: 'Password must contain an uppercase letter',
  })
  @Matches(/(?=.*\d)/, { message: 'Password must contain a number' })
  @Matches(/(?=.*[@$!%*?&._-])/, {
    message: 'Password must contain a special character',
  })
  newPassword: string;
}
