import { Injectable } from '@nestjs/common';

type VoteDirection = 'up' | 'down';

interface TrackVoteCounter {
  upVotes: number;
  downVotes: number;
  updatedAt: Date;
}

@Injectable()
export class TrackVotesRepository {
  private readonly store = new Map<string, TrackVoteCounter>();

  recordVote(
    roomId: string,
    trackId: string,
    vote: VoteDirection,
  ): TrackVoteCounter {
    const key = this.buildKey(roomId, trackId);
    const current = this.store.get(key) ?? {
      upVotes: 0,
      downVotes: 0,
      updatedAt: new Date(),
    };

    const next: TrackVoteCounter = {
      upVotes: current.upVotes,
      downVotes: current.downVotes,
      updatedAt: new Date(),
    };

    if (vote === 'up') {
      next.upVotes += 1;
    } else {
      next.downVotes += 1;
    }

    this.store.set(key, next);
    return next;
  }

  private buildKey(roomId: string, trackId: string): string {
    return `${roomId}::${trackId}`;
  }
}
