import { Test, TestingModule } from '@nestjs/testing';
import { PlaybackService } from './playback.service';
import { NotFoundException } from '@nestjs/common';
import youtubedl from 'youtube-dl-exec';

jest.mock('youtube-dl-exec');

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
      (youtubedl as jest.Mock).mockResolvedValue({
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
      expect(youtubedl).toHaveBeenCalledWith(
        'https://www.youtube.com/watch?v=zUJuVsSR5n4',
        {
          dumpSingleJson: true,
          noCheckCertificates: true,
          noWarnings: true,
          preferFreeFormats: true,
          format: 'bestaudio/best',
        },
      );
    });

    it('should throw NotFoundException when youtubedl fails', async () => {
      (youtubedl as jest.Mock).mockRejectedValue(new Error('YtDlp Error'));

      await expect(service.getDirectAudioUrl('zUJuVsSR5n4')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('should throw NotFoundException when youtubedl returns no url', async () => {
      (youtubedl as jest.Mock).mockResolvedValue({});

      await expect(service.getDirectAudioUrl('zUJuVsSR5n4')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('should throw NotFoundException when youtubedl returns a string', async () => {
      (youtubedl as jest.Mock).mockResolvedValue('some raw output string');

      await expect(service.getDirectAudioUrl('zUJuVsSR5n4')).rejects.toThrow(
        NotFoundException,
      );
    });
  });
});
