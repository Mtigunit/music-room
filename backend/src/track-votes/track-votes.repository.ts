import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

type VoteDirection = 'up' | 'down' | 'none';

export interface TrackVoteCounter {
  score: number;
  updatedAt: Date;
}

@Injectable()
export class TrackVotesRepository {
  constructor(private readonly prisma: PrismaService) {}

  async recordVote(
    eventId: string,
    trackId: string,
    userId: string,
    vote: VoteDirection,
  ): Promise<TrackVoteCounter> {
    const eventTrack = await this.prisma.eventTrack.findUnique({
      where: {
        eventId_trackId: {
          eventId,
          trackId,
        },
      },
    });

    if (!eventTrack) {
      throw new NotFoundException(
        `EventTrack not found for event ${eventId} and track ${trackId}`,
      );
    }

    const eventTrackId = eventTrack.id;

    return this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT * FROM "EventTrack" WHERE id = ${eventTrackId} FOR UPDATE`;

      const previousVote = await tx.vote.findUnique({
        where: {
          eventTrackId_userId: {
            eventTrackId,
            userId,
          },
        },
      });

      let scoreDiff = 0;

      if (vote === 'none') {
        if (previousVote) {
          scoreDiff = -previousVote.voteValue;
          await tx.vote.delete({
            where: {
              eventTrackId_userId: {
                eventTrackId,
                userId,
              },
            },
          });
        }
      } else {
        const newValue = vote === 'up' ? 1 : -1;
        if (previousVote) {
          scoreDiff = newValue - previousVote.voteValue;
          await tx.vote.update({
            where: {
              eventTrackId_userId: {
                eventTrackId,
                userId,
              },
            },
            data: { voteValue: newValue },
          });
        } else {
          scoreDiff = newValue;
          await tx.vote.create({
            data: {
              eventTrackId,
              userId,
              voteValue: newValue,
            },
          });
        }
      }

      const updatedEventTrack = await tx.eventTrack.update({
        where: { id: eventTrackId },
        data: { voteScore: { increment: scoreDiff } },
      });

      return {
        score: updatedEventTrack.voteScore,
        updatedAt: new Date(),
      };
    });
  }
}
