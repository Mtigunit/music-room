import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { ValidateNested } from 'class-validator';
import { TrackSearchResultDto } from '../../tracks/dto/track-search-result.dto';

export class AddTrackToPlaylistDto {
  @ApiProperty({ type: TrackSearchResultDto })
  @ValidateNested()
  @Type(() => TrackSearchResultDto)
  track!: TrackSearchResultDto;
}
