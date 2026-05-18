import { Controller, Get, Param, Logger } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiParam } from '@nestjs/swagger';
import { PlaybackService } from './playback.service';
import { ParseYoutubeIdPipe } from './pipes/parse-youtube-id.pipe';
import { AudioStreamResponseDto } from './dto/audio-stream-response.dto';

@ApiTags('Playback')
@Controller('playback')
export class PlaybackController {
  private readonly logger = new Logger(PlaybackController.name);

  constructor(private readonly playbackService: PlaybackService) {}

  @Get('stream/:youtubeId')
  @ApiOperation({ summary: 'Get direct audio stream URL for a YouTube video' })
  @ApiParam({
    name: 'youtubeId',
    description: 'YouTube Video ID',
    type: String,
  })
  @ApiResponse({
    status: 200,
    description: 'Direct audio stream details returned successfully.',
    type: AudioStreamResponseDto,
  })
  @ApiResponse({
    status: 400,
    description: 'Invalid YouTube video ID format.',
  })
  @ApiResponse({
    status: 404,
    description: 'YouTube video was not found or is unavailable.',
  })
  async getStreamUrl(
    @Param('youtubeId', ParseYoutubeIdPipe) youtubeId: string,
  ): Promise<AudioStreamResponseDto> {
    this.logger.log(
      `Received request to extract stream for YouTube ID: ${youtubeId}`,
    );
    return this.playbackService.getDirectAudioUrl(youtubeId);
  }
}
