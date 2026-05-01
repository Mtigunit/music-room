import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { TrackVoteMessageDto } from './dto/track-vote-message.dto';
import { TrackVoteResultDto } from './dto/track-vote-result.dto';
import {
  TrackVotesRepository,
  TrackVoteCounter,
} from './track-votes.repository';
import { AUDIT_LOG_EVENT, AuditAction } from '../audit-log/audit-log.constants';
import { createAuditLogEvent } from '../audit-log/audit-log.event';
import type { ClientMetaDto } from '../common/dto/client-meta.dto';
import { Visibility, PolicyType } from '@prisma/client';
import { plainToInstance } from 'class-transformer';
import { TimeWindowPolicyConfigDto } from '../events/dto/policies.dto';

// utility function to measure distance
function getDistanceFromLatLonInM(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
) {
  const R = 6371e3; // Earth's radius in meters
  const dLat = (lat2 - lat1) * (Math.PI / 180);
  const dLon = (lon2 - lon1) * (Math.PI / 180);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * (Math.PI / 180)) *
      Math.cos(lat2 * (Math.PI / 180)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const d = R * c; // Distance in meters
  return d;
}

@Injectable()
export class TrackVotesService {
  constructor(
    private readonly trackVotesRepository: TrackVotesRepository,
    private readonly eventEmitter: EventEmitter2,
  ) {}

  async recordVote(
    payload: TrackVoteMessageDto,
    userId: string,
    meta: ClientMetaDto,
  ): Promise<TrackVoteResultDto> {
    const event = await this.trackVotesRepository.getEventForVoting(
      payload.eventId,
    );
    if (!event) {
      throw new NotFoundException(`Event ${payload.eventId} not found`);
    }

    // Check visibility / invites
    const isHost = event.hostId === userId;
    const isInvited = event.invites.some((i) => i.userId === userId);

    if (event.visibility === Visibility.PRIVATE && !isHost && !isInvited) {
      throw new ForbiddenException('You do not have access to this event');
    }

    if (event.invitingOnly && !isHost && !isInvited) {
      throw new ForbiddenException('This event is strictly invite-only');
    }

    // Check policies
    for (const policy of event.policies) {
      if (policy.policyType === PolicyType.TIME_WINDOW) {
        const config = plainToInstance(
          TimeWindowPolicyConfigDto,
          policy.config,
        );
        const now = new Date();

        if (config.startDate != null && now < new Date(config.startDate)) {
          throw new ForbiddenException('Voting has not started yet');
        }
        if (config.endDate != null && now > new Date(config.endDate)) {
          throw new ForbiddenException('Voting is closed');
        }
      }

      if (policy.policyType === PolicyType.GEOFENCE) {
        const config = policy.config as { distance: number };

        if (payload.locationLat == null || payload.locationLng == null) {
          throw new BadRequestException(
            'Location (locationLat, locationLng) is required to vote on this event',
          );
        }

        if (
          event.locationLat != null &&
          event.locationLng != null &&
          typeof config.distance === 'number' &&
          config.distance > 0
        ) {
          const distance = getDistanceFromLatLonInM(
            event.locationLat,
            event.locationLng,
            payload.locationLat,
            payload.locationLng,
          );
          if (distance > config.distance) {
            throw new ForbiddenException(
              'You are not physically close enough to the event location to vote',
            );
          }
        }
      }
    }

    const record: TrackVoteCounter = await this.trackVotesRepository.recordVote(
      payload.eventId,
      payload.trackId,
      userId,
      payload.vote,
    );

    this.eventEmitter.emit(
      AUDIT_LOG_EVENT,
      createAuditLogEvent(userId, AuditAction.VOTE_CAST, meta, {
        eventId: payload.eventId,
        trackId: payload.trackId,
        vote: payload.vote,
      }),
    );

    return {
      eventId: payload.eventId,
      trackId: payload.trackId,
      score: record.score,
      updatedAt: record.updatedAt.toISOString(),
    };
  }
}
