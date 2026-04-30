import { ApiProperty } from '@nestjs/swagger';
import { IsString, MinLength } from 'class-validator';
import { PaginationDto } from '../../common/dto/pagination.dto';

export class SearchUsersDto extends PaginationDto {
  @ApiProperty({ description: 'Username to search for (partial match)' })
  @IsString()
  @MinLength(1)
  q!: string;
}
