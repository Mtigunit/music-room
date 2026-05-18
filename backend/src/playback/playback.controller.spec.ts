import { Test, TestingModule } from '@nestjs/testing';
import { PlaybackController } from './playback.controller';
import { PlaybackService } from './playback.service';

describe('PlaybackController', () => {
  let controller: PlaybackController;
  let service: PlaybackService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [PlaybackController],
      providers: [
        {
          provide: PlaybackService,
          useValue: {
            getDirectAudioUrl: jest.fn().mockResolvedValue({
              url: 'https://mock.audio.stream/url',
              title: 'Mock Video Title',
              duration: 120,
            }),
          },
        },
      ],
    }).compile();

    controller = module.get<PlaybackController>(PlaybackController);
    service = module.get<PlaybackService>(PlaybackService);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  describe('getStreamUrl', () => {
    it('should call getDirectAudioUrl and return the url', async () => {
      const result = await controller.getStreamUrl('zUJuVsSR5n4');

      expect(service.getDirectAudioUrl).toHaveBeenCalledWith('zUJuVsSR5n4');
      expect(result).toEqual({
        url: 'https://mock.audio.stream/url',
        title: 'Mock Video Title',
        duration: 120,
      });
    });
  });
});
