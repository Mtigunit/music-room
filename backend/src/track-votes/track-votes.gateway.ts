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

@WebSocketGateway({ path: '/ws', cors: true })
@UseGuards(WsAuthGuard)
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
  ): Promise<TrackVoteResultDto> {
    const userId = (client.data as { user: { id: string } }).user.id;

    // TODO: check later the licence policies
    if (!client.rooms.has(payload.eventId)) {
      throw new WsException(
        `You must join event room ${payload.eventId} to vote.`,
      );
    }

    const result = await this.trackVotesService.recordVote(payload, userId);
    this.server.to(payload.eventId).emit('track:vote:updated', result);

    this.logger.log(
      `Vote recorded: client=${client.id} userId=${userId} event=${payload.eventId} track=${payload.trackId} vote=${payload.vote}`,
    );

    return result;
  }
}
