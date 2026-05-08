import { ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsString } from 'class-validator';

export class LinkGoogleDto {
  @ApiProperty({
    description: 'The Google ID Token received from Google Sign-In SDK',
    example: 'eyJhbGciOiJSUzI1NiIs...',
  })
  @IsString()
  @IsNotEmpty()
  idToken: string;
}
