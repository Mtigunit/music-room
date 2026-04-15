import { Injectable } from '@nestjs/common';
import { RedisService } from '../redis/redis.service';

type VoteDirection = 'up' | 'down' | 'none';

export interface TrackVoteCounter {
  upVotes: number;
  downVotes: number;
  updatedAt: Date;
}

@Injectable()
export class TrackVotesRepository {
  constructor(private readonly redisService: RedisService) {}

  async recordVote(
    roomId: string,
    trackId: string,
    userId: string,
    vote: VoteDirection,
  ): Promise<TrackVoteCounter> {
    const client = this.redisService.getClient();
    const roomTrackKey = this.buildKey(roomId, trackId);
    const userVoteKey = `${roomTrackKey}:user:${userId}`;

    // 1) Find out if the user already voted & what their old vote was
    const oldVote = (await client.get(userVoteKey)) as VoteDirection | null;
    const normalizedOldVote = oldVote || 'none';

    // If the user is voting the exact same direction again, do nothing (idempotent)
    if (normalizedOldVote === vote) {
      const current = await client.hgetall(roomTrackKey);
      return {
        upVotes: parseInt(current.upVotes || '0', 10),
        downVotes: parseInt(current.downVotes || '0', 10),
        updatedAt: new Date(),
      };
    }

    // 2) Prepare the pipeline
    const pipeline = client.multi();

    // Apply the NEW vote (if they aren't just removing it)
    if (vote !== 'none') {
      const newField = vote === 'up' ? 'upVotes' : 'downVotes';
      const scoreDiff = vote === 'up' ? 1 : -1;

      pipeline.hincrby(roomTrackKey, newField, 1);
      pipeline.hincrby(roomTrackKey, 'score', scoreDiff);
      pipeline.set(userVoteKey, vote);
    } else {
      // Removing their vote entirely
      pipeline.del(userVoteKey);
    }

    // 3) Subtract the OLD vote (if they had one)
    if (oldVote && oldVote !== 'none') {
      const oldField = oldVote === 'up' ? 'upVotes' : 'downVotes';
      const oldScoreDiff = oldVote === 'up' ? -1 : 1;
      pipeline.hincrby(roomTrackKey, oldField, -1);
      pipeline.hincrby(roomTrackKey, 'score', oldScoreDiff);
    }

    // 4) Fetch the final updated counts
    pipeline.hgetall(roomTrackKey);

    const execResult = (await pipeline.exec()) ?? [];
    if (!execResult || execResult[0]?.[0]) {
      throw new Error('Failed to record vote in Redis');
    }

    // The hgetall result is always the LAST command executed in our pipeline
    const current = execResult[execResult.length - 1][1] as Record<
      string,
      string
    >;

    return {
      upVotes: parseInt(current.upVotes || '0', 10),
      downVotes: parseInt(current.downVotes || '0', 10),
      updatedAt: new Date(),
    };
  }

  private buildKey(roomId: string, trackId: string): string {
    return `track-votes:${roomId}:${trackId}`;
  }
}
