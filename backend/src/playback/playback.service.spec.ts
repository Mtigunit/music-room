import { Test, TestingModule } from '@nestjs/testing';
import { NotFoundException, RequestTimeoutException } from '@nestjs/common';

const mockYoutubedl = jest.fn();
(global as any).mockYoutubedl = mockYoutubedl;

jest.mock('youtube-dl-exec', () => ({
  __esModule: true,
  default: (global as any).mockYoutubedl,
}));

import { PlaybackService } from './playback.service';

describe('PlaybackService', () => {
  let service: PlaybackService;

  beforeEach(async () => {
    jest.clearAllMocks();
    const module: TestingModule = await Test.createTestingModule({
      providers: [PlaybackService],
    }).compile();

    service = module.get<PlaybackService>(PlaybackService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('getDirectAudioUrl', () => {
    it('should return a direct audio url', async () => {
      const mockUrl = 'https://mock.audio.stream/url';
      const mockTitle = 'Mock Video Title';
      const mockDuration = 120;
      mockYoutubedl.mockResolvedValue({
        url: mockUrl,
        title: mockTitle,
        duration: mockDuration,
      });

      const result = await service.getDirectAudioUrl('zUJuVsSR5n4');

      expect(result).toEqual({
        url: mockUrl,
        title: mockTitle,
        duration: mockDuration,
      });
      expect(mockYoutubedl).toHaveBeenCalledWith(
        'https://www.youtube.com/watch?v=zUJuVsSR5n4',
        {
          dumpSingleJson: true,
          noWarnings: true,
          preferFreeFormats: true,
          format: 'bestaudio/best',
          extractorArgs: 'youtube:player_client=android',
        },
      );
    });

    it('should throw NotFoundException when youtubedl fails', async () => {
      mockYoutubedl.mockRejectedValue(new Error('YtDlp Error'));

      await expect(service.getDirectAudioUrl('zUJuVsSR5n4')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('should throw NotFoundException when youtubedl returns no url', async () => {
      mockYoutubedl.mockResolvedValue({});

      await expect(service.getDirectAudioUrl('zUJuVsSR5n4')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('should throw NotFoundException when youtubedl returns a string', async () => {
      mockYoutubedl.mockResolvedValue('some raw output string');

      await expect(service.getDirectAudioUrl('zUJuVsSR5n4')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('should throw RequestTimeoutException when youtubedl times out', async () => {
      jest.useFakeTimers();

      const pendingPromise = new Promise(() => {}); // never resolves
      mockYoutubedl.mockReturnValue(pendingPromise);

      const promise = service.getDirectAudioUrl('zUJuVsSR5n4');

      // Fast-forward time by 10 seconds
      jest.advanceTimersByTime(10000);

      await expect(promise).rejects.toThrow(RequestTimeoutException);

      jest.useRealTimers();
    });
  });
});
