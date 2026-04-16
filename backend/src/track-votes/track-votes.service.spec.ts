import { Test, TestingModule } from '@nestjs/testing';
import { TrackVotesService } from './track-votes.service';
import { TrackVotesRepository } from './track-votes.repository';
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
      ],
    }).compile();

    service = module.get<TrackVotesService>(TrackVotesService);
    repository = module.get(TrackVotesRepository);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('recordVote', () => {
    it('should correctly format and return the vote result', async () => {
      // Arrange
      const payload: TrackVoteMessageDto = {
        eventId: 'event-123',
        trackId: 'track-456',
        vote: 'up',
      };

      const mockDate = new Date('2026-04-15T10:00:00.000Z');
      repository.recordVote.mockResolvedValue({
        upVotes: 5,
        downVotes: 2,
        updatedAt: mockDate,
      });

      // Act
      const result = await service.recordVote(payload, 'user-123');

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
        upVotes: 5,
        downVotes: 2,
        score: 3, // 5 - 2
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
        upVotes: 10,
        downVotes: 15,
        updatedAt: new Date(),
      });

      // Act
      const result = await service.recordVote(payload, 'user-456');

      // Assert
      expect(result.score).toBe(-5);
    });
  });
});
