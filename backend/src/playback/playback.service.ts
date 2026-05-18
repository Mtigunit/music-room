import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import youtubedl, { Payload } from 'youtube-dl-exec';
import { AudioStreamResponseDto } from './dto/audio-stream-response.dto';

export interface YtDlpResponse extends Payload {
  url: string;
}

@Injectable()
export class PlaybackService {
  private readonly logger = new Logger(PlaybackService.name);

  async getDirectAudioUrl(youtubeId: string): Promise<AudioStreamResponseDto> {
    const url = `https://www.youtube.com/watch?v=${youtubeId}`;
    try {
      this.logger.log(`Extracting audio stream for YouTube ID: ${youtubeId}`);

      const output = await youtubedl(url, {
        dumpSingleJson: true,
        noCheckCertificates: true,
        noWarnings: true,
        preferFreeFormats: true,
        format: 'bestaudio/best',
      });

      if (typeof output === 'string') {
        throw new Error(
          'Received string output instead of JSON from youtube-dl-exec',
        );
      }

      const mediaInfo = output as YtDlpResponse;

      if (!mediaInfo || !mediaInfo.url) {
        throw new Error('No URL returned from youtube-dl-exec');
      }

      this.logger.log(
        `Successfully extracted stream URL for YouTube ID: ${youtubeId}`,
      );
      return {
        url: mediaInfo.url,
        title: mediaInfo.title,
        duration: mediaInfo.duration,
      };
    } catch (error) {
      this.logger.error(
        `Failed to extract audio for YouTube ID: ${youtubeId}`,
        error,
      );
      throw new NotFoundException('Video not found or unavailable');
    }
  }
}
