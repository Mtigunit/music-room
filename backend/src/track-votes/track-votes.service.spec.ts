import { Test, TestingModule } from '@nestjs/testing';
import { TrackVotesService } from './track-votes.service';
import { TrackVotesRepository } from './track-votes.repository';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { TrackVoteMessageDto } from './dto/track-vote-message.dto';

describe('TrackVotesService', () => {
  let service: TrackVotesService;
  let repository: jest.Mocked<TrackVotesRepository>;

  beforeEach(async () => {
    // Create a mock repository
    const mockRepository = {
      recordVote: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TrackVotesService,
        {
          provide: TrackVotesRepository,
          useValue: mockRepository,
        },
        {
          provide: EventEmitter2,
          useValue: { emit: jest.fn() },
        },
      ],
    }).compile();

    service = module.get<TrackVotesService>(TrackVotesService);
    repository = module.get(TrackVotesRepository);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('recordVote', () => {
    const mockMeta = {
      platform: 'unknown',
      deviceModel: 'unknown',
      appVersion: 'unknown',
      ipAddress: '127.0.0.1',
    };

    it('should correctly format and return the vote result', async () => {
      // Arrange
      const payload: TrackVoteMessageDto = {
        eventId: 'event-123',
        trackId: 'track-456',
        vote: 'up',
      };

      const mockDate = new Date('2026-04-15T10:00:00.000Z');
      repository.recordVote.mockResolvedValue({
        score: 3,
        updatedAt: mockDate,
      });

      // Act
      const result = await service.recordVote(payload, 'user-123', mockMeta);

      // Assert
      expect(repository.recordVote).toHaveBeenCalledWith(
        payload.eventId,
        payload.trackId,
        'user-123',
        payload.vote,
      );

      expect(result).toEqual({
        eventId: 'event-123',
        trackId: 'track-456',
        score: 3,
        updatedAt: mockDate.toISOString(),
      });
    });

    it('should handle negative scores correctly', async () => {
      // Arrange
      const payload: TrackVoteMessageDto = {
        eventId: 'event-789',
        trackId: 'track-012',
        vote: 'down',
      };

      repository.recordVote.mockResolvedValue({
        score: -5,
        updatedAt: new Date(),
      });

      // Act
      const result = await service.recordVote(payload, 'user-456', mockMeta);

      // Assert
      expect(result.score).toBe(-5);
    });
  });
});
