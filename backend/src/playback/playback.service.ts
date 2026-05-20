import {
  Injectable,
  Logger,
  NotFoundException,
  RequestTimeoutException,
} from '@nestjs/common';
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
    let timeoutId: NodeJS.Timeout | null = null;

    try {
      this.logger.log(`Extracting audio stream for YouTube ID: ${youtubeId}`);

      const youtubedlPromise = youtubedl(url, {
        dumpSingleJson: true,
        noWarnings: true,
        preferFreeFormats: true,
        format: 'bestaudio/best',
      });

      const timeoutPromise = new Promise<never>((_, reject) => {
        timeoutId = setTimeout(() => {
          reject(new Error('YtDlp extraction timed out'));
        }, 10000); // 10 seconds timeout limit
      });

      const output = await Promise.race([youtubedlPromise, timeoutPromise]);

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
      if (
        error instanceof Error &&
        error.message === 'YtDlp extraction timed out'
      ) {
        throw new RequestTimeoutException('Audio extraction timed out');
      }
      throw new NotFoundException('Video not found or unavailable');
    } finally {
      if (timeoutId) {
        clearTimeout(timeoutId);
      }
    }
  }
}
