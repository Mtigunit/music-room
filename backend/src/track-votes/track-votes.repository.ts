import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

type VoteDirection = 'up' | 'down' | 'none';

export interface TrackVoteCounter {
  upVotes: number;
  downVotes: number;
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
    const eventTrack = await this.prisma.eventTrack.findFirst({
      where: {
        eventId,
        trackId,
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

      if (vote === 'none') {
        await tx.vote.deleteMany({
          where: {
            eventTrackId,
            userId,
          },
        });
      } else {
        const voteValue = vote === 'up' ? 1 : -1;
        await tx.vote.upsert({
          where: {
            eventTrackId_userId: {
              eventTrackId,
              userId,
            },
          },
          update: {
            voteValue,
          },
          create: {
            eventTrackId,
            userId,
            voteValue,
          },
        });
      }

      const allVotes = await tx.vote.findMany({
        where: { eventTrackId },
        select: { voteValue: true },
      });

      let upVotes = 0;
      let downVotes = 0;
      let score = 0;

      for (const v of allVotes) {
        if (v.voteValue === 1) upVotes++;
        else if (v.voteValue === -1) downVotes++;
        score += v.voteValue;
      }

      await tx.eventTrack.update({
        where: { id: eventTrackId },
        data: { voteScore: score },
      });

      return {
        upVotes,
        downVotes,
        updatedAt: new Date(),
      };
    });
  }
}
