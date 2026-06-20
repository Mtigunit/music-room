import { ApiProperty } from '@nestjs/swagger';
import { IsString, MaxLength } from 'class-validator';

export class AppendedTrackDto {
  @ApiProperty()
  @IsString()
  @MaxLength(100)
  providerTrackId!: string;
}
