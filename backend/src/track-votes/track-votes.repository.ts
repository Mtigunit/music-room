import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { TrackStatus, SubscriptionTier, Prisma } from '@prisma/client';
import { MAX_VOTES_PER_EVENT } from '../events/events.constants';

type VoteDirection = 'up' | 'down' | 'none';

export interface TrackVoteCounter {
  score: number;
  updatedAt: Date;
}

export class TrackNotFoundError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'TrackNotFoundError';
  }
}

export class TrackNotQueuedError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'TrackNotQueuedError';
  }
}

export class MaxVotesReachedError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'MaxVotesReachedError';
  }
}

export class UserNotFoundError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'UserNotFoundError';
  }
}

@Injectable()
export class TrackVotesRepository {
  constructor(private readonly prisma: PrismaService) {}

  async getEventForVoting(eventId: string) {
    return this.prisma.event.findUnique({
      where: { id: eventId },
      include: {
        policies: true,
        invites: {
          select: { userId: true },
        },
      },
    });
  }

  async recordVote(
    eventId: string,
    trackId: string,
    userId: string,
    vote: VoteDirection,
  ): Promise<TrackVoteCounter> {
    const eventTrack = await this.prisma.eventTrack.findUnique({
      where: { eventId_trackId: { eventId, trackId } },
      select: { id: true, status: true },
    });

    if (!eventTrack) {
      throw new TrackNotFoundError(
        `EventTrack not found for event ${eventId} and track ${trackId}`,
      );
    }
    if (eventTrack.status !== TrackStatus.QUEUED) {
      throw new TrackNotQueuedError(
        `Cannot vote on track ${trackId}: it is not queued.`,
      );
    }

    const eventTrackId = eventTrack.id;

    return this.prisma.$transaction(async (tx) => {
      // --- Serialization point for (userId, eventId) ---
      // Generates a stable integer key from the two UUIDs.
      // pg_advisory_xact_lock is transaction-scoped: releases automatically on commit/rollback.
      // It blocks and waits if the lock is held, effectively queuing concurrent requests.
      const userHash = this.buildAdvisoryLockHash(userId);
      const eventHash = this.buildAdvisoryLockHash(eventId);

      await tx.$executeRaw(
        Prisma.sql`SELECT pg_advisory_xact_lock(${userHash}::int4, ${eventHash}::int4)`,
      );
      // ─────────────────────────────────────────────────
      const lockedTracks = await tx.$queryRaw<
        Array<{ voteScore: number; status: TrackStatus }>
      >(
        Prisma.sql`
        SELECT "voteScore", "status"
        FROM "EventTrack"
        WHERE id = ${eventTrackId}
        FOR UPDATE
      `,
      );
      const lockedTrack = lockedTracks[0];

      if (!lockedTrack) {
        throw new TrackNotFoundError(
          `EventTrack ${eventTrackId} no longer exists`,
        );
      }

      if (lockedTrack.status !== TrackStatus.QUEUED) {
        throw new TrackNotQueuedError(
          `Cannot vote on track ${trackId}: it is no longer queued.`,
        );
      }

      const currentScore = lockedTrack.voteScore;

      const previousVote = await tx.vote.findUnique({
        where: { eventTrackId_userId: { eventTrackId, userId } },
      });

      if (vote !== 'none' && !previousVote) {
        const user = await tx.user.findUnique({
          where: { id: userId },
          select: { subscriptionTier: true },
        });

        if (!user) {
          throw new UserNotFoundError(`User ${userId} not found`);
        }

        if (user.subscriptionTier === SubscriptionTier.BASIC) {
          const userVoteCount = await tx.vote.count({
            where: { userId, eventTrack: { eventId } },
          });

          if (userVoteCount >= MAX_VOTES_PER_EVENT) {
            throw new MaxVotesReachedError(
              'You have reached the maximum number of votes for this event.',
            );
          }
        }
      }

      let scoreDiff = 0;

      if (vote === 'none') {
        if (previousVote) {
          scoreDiff = -previousVote.voteValue;
          await tx.vote.delete({
            where: { eventTrackId_userId: { eventTrackId, userId } },
          });
        }
      } else {
        const newValue = vote === 'up' ? 1 : -1;

        if (previousVote) {
          scoreDiff = newValue - previousVote.voteValue;
          if (scoreDiff !== 0) {
            await tx.vote.update({
              where: { eventTrackId_userId: { eventTrackId, userId } },
              data: { voteValue: newValue },
            });
          }
        } else {
          scoreDiff = newValue;
          await tx.vote.create({
            data: { eventTrackId, userId, voteValue: newValue },
          });
        }
      }

      if (scoreDiff === 0) {
        return { score: currentScore, updatedAt: new Date() };
      }

      const updatedEventTrack = await tx.eventTrack.update({
        where: { id: eventTrackId },
        data: { voteScore: { increment: scoreDiff } },
      });

      return { score: updatedEventTrack.voteScore, updatedAt: new Date() };
    });
  }

  private buildAdvisoryLockHash(s: string): number {
    let h = 0;
    for (const c of s) {
      h = Math.imul(h, 31) + c.charCodeAt(0);
    }
    // Coerce to signed int32 (what PostgreSQL's int4 expects)
    return h | 0;
  }
}
