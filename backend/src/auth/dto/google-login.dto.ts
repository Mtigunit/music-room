import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString } from 'class-validator';

export class GoogleLoginDto {
  @ApiProperty({
    description: 'The Google ID Token received from the mobile client',
    example: 'eyJhbGciOiJSUzI1NiIs...',
  })
  @IsString()
  @IsNotEmpty()
  idToken: string;
}
