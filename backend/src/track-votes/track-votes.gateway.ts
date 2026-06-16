import {
  ConnectedSocket,
  MessageBody,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
  WsException,
} from '@nestjs/websockets';
import {
  Logger,
  UseGuards,
  UsePipes,
  ValidationPipe,
  HttpException,
} from '@nestjs/common';
import { Server, Socket } from 'socket.io';
import { TrackVotesService } from './track-votes.service';
import { TrackVoteMessageDto } from './dto/track-vote-message.dto';
import { TrackVoteResultDto } from './dto/track-vote-result.dto';
import {
  TrackNotFoundError,
  TrackNotQueuedError,
  MaxVotesReachedError,
} from './track-votes.repository';
import { WsAuthGuard } from '../websockets/guards/ws-auth.guard';
import { WsThrottlerGuard } from '../websockets/guards/ws-throttler.guard';
import { WsUser } from '../websockets/decorators/ws-user.decorator';
import type { SocketUser } from '../websockets/socket-auth.service';
import type { ClientMetaDto } from '../common/dto/client-meta.dto';
import { ClientMeta } from '../common/decorators/client-meta.decorator';
import { WS_EVENTS } from '../events/events.constants';

@WebSocketGateway({ path: '/ws', cors: true })
@UseGuards(WsAuthGuard, WsThrottlerGuard)
export class TrackVotesGateway {
  @WebSocketServer()
  server!: Server;
  private readonly logger = new Logger(TrackVotesGateway.name);

  constructor(private readonly trackVotesService: TrackVotesService) {}

  @SubscribeMessage(WS_EVENTS.TRACK_VOTE)
  @UsePipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      exceptionFactory: (errors) =>
        new WsException(
          errors.map((e) => Object.values(e.constraints ?? {})).flat(),
        ),
    }),
  )
  async handleTrackVote(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: TrackVoteMessageDto,
    @WsUser() user: SocketUser,
    @ClientMeta() meta: ClientMetaDto,
  ): Promise<TrackVoteResultDto> {
    const userId = user.id;

    // TODO: check later the license policies
    if (!client.rooms.has(`event_${payload.eventId}`)) {
      throw new WsException(
        `You must join event room event_${payload.eventId} to vote.`,
      );
    }

    try {
      const result = await this.trackVotesService.recordVote(
        payload,
        userId,
        meta,
      );

      this.server
        .to(`event_${payload.eventId}`)
        .emit(WS_EVENTS.TRACK_VOTE_UPDATED, result);

      this.logger.log(
        `Vote recorded: client=${client.id} userId=${userId} event=${payload.eventId} track=${payload.trackId} vote=${payload.vote}`,
      );

      return result;
    } catch (error) {
      if (
        error instanceof TrackNotFoundError ||
        error instanceof TrackNotQueuedError ||
        error instanceof MaxVotesReachedError
      ) {
        throw new WsException(error.message);
      }
      if (error instanceof HttpException) {
        throw new WsException(error.message);
      }
      throw error;
    }
  }
}
