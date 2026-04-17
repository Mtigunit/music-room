import { BadRequestException, Controller, Get, Query } from '@nestjs/common';
import { ApiOperation, ApiQuery, ApiResponse, ApiTags } from '@nestjs/swagger';
import { YoutubeService } from './youtube.service';
import { TrackSearchResultDto } from './dto/track-search-result.dto';

@ApiTags('Tracks')
@Controller('tracks')
export class TracksController {
  constructor(private readonly youtubeService: YoutubeService) {}

  @Get('search')
  @ApiOperation({ summary: 'Search YouTube music tracks' })
  @ApiQuery({ name: 'q', type: String, required: true })
  @ApiResponse({
    status: 200,
    description: 'Search results for tracks.',
    type: TrackSearchResultDto,
    isArray: true,
  })
  @ApiResponse({ status: 400, description: 'Invalid search query.' })
  @ApiResponse({ status: 500, description: 'YouTube API error.' })
  async search(@Query('q') query: string): Promise<TrackSearchResultDto[]> {
    if (!query || query.trim().length === 0) {
      throw new BadRequestException('Query parameter "q" is required');
    }

    return this.youtubeService.searchMusic(query.trim());
  }
}
