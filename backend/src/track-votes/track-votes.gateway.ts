import {
  ConnectedSocket,
  MessageBody,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
  WsException,
} from '@nestjs/websockets';
import { Logger, UseGuards, UsePipes, ValidationPipe } from '@nestjs/common';
import { Server, Socket } from 'socket.io';
import { TrackVotesService } from './track-votes.service';
import { TrackVoteMessageDto } from './dto/track-vote-message.dto';
import { TrackVoteResultDto } from './dto/track-vote-result.dto';
import { WsAuthGuard } from '../websockets/guards/ws-auth.guard';
import { WsThrottlerGuard } from '../websockets/guards/ws-throttler.guard';
import { WsUser } from '../websockets/decorators/ws-user.decorator';
import type { SocketUser } from '../websockets/socket-auth.service';
import type { ClientMetaDto } from '../common/dto/client-meta.dto';
import { ClientMeta } from '../common/decorators/client-meta.decorator';

@WebSocketGateway({ path: '/ws', cors: true })
@UseGuards(WsAuthGuard, WsThrottlerGuard)
export class TrackVotesGateway {
  @WebSocketServer()
  server!: Server;
  private readonly logger = new Logger(TrackVotesGateway.name);

  constructor(private readonly trackVotesService: TrackVotesService) {}

  @SubscribeMessage('track:vote')
  @UsePipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
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
    if (!client.rooms.has(payload.eventId)) {
      throw new WsException(
        `You must join event room ${payload.eventId} to vote.`,
      );
    }

    const result = await this.trackVotesService.recordVote(
      payload,
      userId,
      meta,
    );
    this.server.to(payload.eventId).emit('track:vote:updated', result);

    this.logger.log(
      `Vote recorded: client=${client.id} userId=${userId} event=${payload.eventId} track=${payload.trackId} vote=${payload.vote}`,
    );

    return result;
  }
}
