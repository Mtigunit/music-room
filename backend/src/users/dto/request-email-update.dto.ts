import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsNotEmpty, IsString, MinLength } from 'class-validator';

export class RequestEmailUpdateDto {
  @ApiProperty({ example: 'new.email@example.com' })
  @IsEmail()
  @IsNotEmpty()
  newEmail: string;

  @ApiProperty({ example: 'currentPassword123' })
  @IsString()
  @IsNotEmpty()
  @MinLength(8)
  password: string;
}
