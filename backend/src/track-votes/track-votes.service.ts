import { Injectable } from '@nestjs/common';
import { TrackVoteMessageDto } from './dto/track-vote-message.dto';
import { TrackVoteResultDto } from './dto/track-vote-result.dto';
import { TrackVotesRepository } from './track-votes.repository';

@Injectable()
export class TrackVotesService {
  constructor(private readonly trackVotesRepository: TrackVotesRepository) {}

  async recordVote(
    payload: TrackVoteMessageDto,
    userId: string,
  ): Promise<TrackVoteResultDto> {
    const record = await this.trackVotesRepository.recordVote(
      payload.roomId,
      payload.trackId,
      userId,
      payload.vote,
    );

    return {
      roomId: payload.roomId,
      trackId: payload.trackId,
      upVotes: record.upVotes,
      downVotes: record.downVotes,
      score: record.upVotes - record.downVotes,
      updatedAt: record.updatedAt.toISOString(),
    };
  }
}
