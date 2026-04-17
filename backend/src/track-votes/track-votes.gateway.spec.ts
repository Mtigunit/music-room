import { Test, TestingModule } from '@nestjs/testing';
import { TrackVotesGateway } from './track-votes.gateway';
import { TrackVotesService } from './track-votes.service';
import { TrackVoteMessageDto } from './dto/track-vote-message.dto';
import { TrackVoteResultDto } from './dto/track-vote-result.dto';
import { Server, Socket } from 'socket.io';
import { WsAuthGuard } from '../websockets/guards/ws-auth.guard';

describe('TrackVotesGateway', () => {
  let gateway: TrackVotesGateway;
  let service: jest.Mocked<TrackVotesService>;

  beforeEach(async () => {
    // Mock the WS Auth Guard to bypass it during the test
    const mockAuthGuard = {
      canActivate: () => true,
    };

    const mockService = {
      recordVote: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TrackVotesGateway,
        {
          provide: TrackVotesService,
          useValue: mockService,
        },
      ],
    })
      .overrideGuard(WsAuthGuard)
      .useValue(mockAuthGuard)
      .compile();

    gateway = module.get<TrackVotesGateway>(TrackVotesGateway);
    service = module.get(TrackVotesService);

    // Mock the WebSocket server
    gateway.server = {
      to: jest.fn().mockReturnThis(),
      emit: jest.fn(),
    } as unknown as Server;
  });

  it('should be defined', () => {
    expect(gateway).toBeDefined();
  });

  describe('handleTrackVote', () => {
    it('should record a vote and broadcast to the room', async () => {
      // Arrange
      const payload: TrackVoteMessageDto = {
        eventId: 'event-123',
        trackId: 'track-456',
        vote: 'up',
      };

      const mockResult: TrackVoteResultDto = {
        eventId: 'event-123',
        trackId: 'track-456',
        score: 3,
        updatedAt: '2026-04-15T10:00:00.000Z',
      };

      service.recordVote.mockResolvedValue(mockResult);

      const mockClient = {
        id: 'socket-999',
        data: {
          user: { id: 'user-123' },
        },
        rooms: new Set(['event-123']),
      } as unknown as Socket;

      // Act
      const result = await gateway.handleTrackVote(mockClient, payload);

      // Assert
      expect(service.recordVote).toHaveBeenCalledWith(payload, 'user-123');

      // Verify the broadcast behavior
      expect(gateway.server.to).toHaveBeenCalledWith('event-123');
      expect(gateway.server.emit).toHaveBeenCalledWith(
        'track:vote:updated',
        mockResult,
      );

      // Function should return the result for the emitter's acknowledgement
      expect(result).toEqual(mockResult);
    });
  });
});
