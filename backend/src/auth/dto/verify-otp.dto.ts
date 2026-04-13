import { IsEmail, IsString, Length } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class VerifyOtpDto {
  @ApiProperty({ example: 'user@example.com' })
  @IsEmail()
  email!: string;

  @ApiProperty({ example: '472915', description: '6-digit OTP code' })
  @IsString()
  @Length(6, 6, { message: 'OTP code must be exactly 6 digits' })
  code!: string;
}
