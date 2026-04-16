import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsNotEmpty, IsString, Length } from 'class-validator';

export class VerifyResetOtpDto {
  @ApiProperty({
    description: 'The email address associated with the account',
    example: 'user@example.com',
  })
  @IsEmail()
  @IsNotEmpty()
  email: string;

  @ApiProperty({
    description: 'The 6-digit OTP code received in the email',
    example: '472915',
    minLength: 6,
    maxLength: 6,
  })
  @IsString()
  @Length(6, 6)
  @IsNotEmpty()
  code: string;
}
