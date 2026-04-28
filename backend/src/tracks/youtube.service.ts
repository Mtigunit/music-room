import {
  Injectable,
  InternalServerErrorException,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { google, youtube_v3 } from 'googleapis';
import { TrackSearchResultDto } from './dto/track-search-result.dto';

@Injectable()
export class YoutubeService {
  private readonly logger = new Logger(YoutubeService.name);
  private readonly youtube: youtube_v3.Youtube;

  constructor(private readonly configService: ConfigService) {
    const apiKey = this.configService.getOrThrow<string>('YOUTUBE_API_KEY');

    this.youtube = google.youtube({
      version: 'v3',
      auth: apiKey,
    });
  }

  async searchMusic(query: string): Promise<TrackSearchResultDto[]> {
    try {
      const searchResponse = await this.youtube.search.list({
        part: ['id', 'snippet'],
        q: query,
        videoCategoryId: '10',
        type: ['video'],
        maxResults: 10,
      });

      const searchItems = searchResponse.data.items ?? [];
      const videoIds = searchItems
        .map((item) => item.id?.videoId)
        .filter((id): id is string => typeof id === 'string' && id.length > 0);

      if (videoIds.length === 0) {
        return [];
      }

      const videosResponse = await this.youtube.videos.list({
        part: ['contentDetails', 'snippet'],
        id: videoIds,
      });

      const videoItems = videosResponse.data.items ?? [];

      return videoItems
        .map((item) => this.mapVideoToTrackResult(item))
        .filter((item): item is TrackSearchResultDto => item !== null);
    } catch (error) {
      const trace =
        error instanceof Error
          ? error.stack
          : `Unknown error: ${String(error)}`;

      this.logger.error('YouTube API request failed', trace);

      if (this.isQuotaExceeded(error)) {
        throw new ServiceUnavailableException(
          'YouTube API quota exceeded. Search is temporarily unavailable.',
        );
      }

      throw new InternalServerErrorException(
        'Failed to fetch YouTube search results',
      );
    }
  }

  async getTrackDetails(
    providerTrackId: string,
  ): Promise<TrackSearchResultDto | null> {
    try {
      const videosResponse = await this.youtube.videos.list({
        part: ['contentDetails', 'snippet'],
        id: [providerTrackId],
      });

      const videoItems = videosResponse.data.items ?? [];
      if (videoItems.length === 0) {
        return null;
      }

      return this.mapVideoToTrackResult(videoItems[0]);
    } catch (error) {
      const trace =
        error instanceof Error
          ? error.stack
          : `Unknown error: ${String(error)}`;

      this.logger.error('YouTube API details request failed', trace);

      if (this.isQuotaExceeded(error)) {
        throw new ServiceUnavailableException(
          'YouTube API quota exceeded. Track details are temporarily unavailable.',
        );
      }

      throw new InternalServerErrorException(
        'Failed to fetch YouTube track details',
      );
    }
  }

  async getTrackDetailsBatch(
    providerTrackIds: string[],
  ): Promise<(TrackSearchResultDto | null)[]> {
    try {
      const videosResponse = await this.youtube.videos.list({
        part: ['contentDetails', 'snippet'],
        id: providerTrackIds,
      });

      const videoItems = videosResponse.data.items ?? [];

      // Build a map for O(1) lookup by video ID
      const videoMap = new Map(videoItems.map((item) => [item.id, item]));

      // Preserve input order and inject null for missing/unavailable videos
      return providerTrackIds.map((id) => {
        const item = videoMap.get(id);
        return item ? this.mapVideoToTrackResult(item) : null;
      });
    } catch (error) {
      const trace =
        error instanceof Error
          ? error.stack
          : `Unknown error: ${String(error)}`;

      this.logger.error('YouTube API batch details request failed', trace);

      if (this.isQuotaExceeded(error)) {
        throw new ServiceUnavailableException(
          'YouTube API quota exceeded. Track details are temporarily unavailable.',
        );
      }

      throw new InternalServerErrorException(
        'Failed to fetch YouTube track details',
      );
    }
  }

  private mapVideoToTrackResult(
    item: youtube_v3.Schema$Video,
  ): TrackSearchResultDto | null {
    const providerTrackId = typeof item.id === 'string' ? item.id : undefined;
    const title =
      typeof item.snippet?.title === 'string' ? item.snippet.title : undefined;
    const artist =
      typeof item.snippet?.channelTitle === 'string'
        ? item.snippet.channelTitle
        : undefined;
    const durationIso =
      typeof item.contentDetails?.duration === 'string'
        ? item.contentDetails.duration
        : undefined;
    const thumbnailUrl = this.pickBestThumbnail(item.snippet?.thumbnails);

    if (!providerTrackId || !title || !artist || !durationIso) {
      return null;
    }

    return {
      providerTrackId,
      title,
      artist,
      durationMs: this.parseIsoDurationToMs(durationIso),
      thumbnailUrl,
    };
  }

  private pickBestThumbnail(
    thumbnails: youtube_v3.Schema$ThumbnailDetails | null | undefined,
  ): string | undefined {
    const url =
      thumbnails?.maxres?.url ??
      thumbnails?.high?.url ??
      thumbnails?.medium?.url ??
      thumbnails?.standard?.url ??
      thumbnails?.default?.url;

    return url ?? undefined;
  }

  private parseIsoDurationToMs(duration: string): number {
    const match = /^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$/.exec(duration);

    if (!match) {
      return 0;
    }

    const hours = match[1] ? Number(match[1]) : 0;
    const minutes = match[2] ? Number(match[2]) : 0;
    const seconds = match[3] ? Number(match[3]) : 0;

    return (hours * 3600 + minutes * 60 + seconds) * 1000;
  }
  private isQuotaExceeded(error: unknown): boolean {
    const errorMessage =
      error instanceof Error ? error.message.toLowerCase() : '';

    const isApiError =
      typeof error === 'object' && error !== null && 'code' in error;
    const is403 = isApiError && (error as Record<string, unknown>).code === 403;

    return errorMessage.includes('quota') || is403;
  }
}
