import { Injectable } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { TrackVoteMessageDto } from './dto/track-vote-message.dto';
import { TrackVoteResultDto } from './dto/track-vote-result.dto';
import { TrackVotesRepository } from './track-votes.repository';
import { AUDIT_LOG_EVENT, AuditAction } from '../audit-log/audit-log.constants';
import type { AuditLogEvent } from '../audit-log/audit-log.event';

@Injectable()
export class TrackVotesService {
  constructor(
    private readonly trackVotesRepository: TrackVotesRepository,
    private readonly eventEmitter: EventEmitter2,
  ) {}

  async recordVote(
    payload: TrackVoteMessageDto,
    userId: string,
  ): Promise<TrackVoteResultDto> {
    const record = await this.trackVotesRepository.recordVote(
      payload.eventId,
      payload.trackId,
      userId,
      payload.vote,
    );

    this.eventEmitter.emit(AUDIT_LOG_EVENT, {
      userId,
      action: AuditAction.VOTE_CAST,
      platform: 'unknown',
      deviceModel: 'unknown',
      appVersion: 'unknown',
      metadata: {
        eventId: payload.eventId,
        trackId: payload.trackId,
        vote: payload.vote,
      },
    } satisfies AuditLogEvent);

    return {
      eventId: payload.eventId,
      trackId: payload.trackId,
      score: record.score,
      updatedAt: record.updatedAt.toISOString(),
    };
  }
}
