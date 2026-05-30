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
import { WsAuthGuard } from '../websockets/guards/ws-auth.guard';
import { PlaylistsRepository } from './playlists.repository';
import { Visibility } from '@prisma/client';
import { WsUser } from '../websockets/decorators/ws-user.decorator';
import type { SocketUser } from '../websockets/socket-auth.service';
import { PlaylistRoomDto } from './dto/playlist-room.dto';

@UsePipes(new ValidationPipe({ transform: true, whitelist: true }))
@WebSocketGateway({ path: '/ws', cors: true })
@UseGuards(WsAuthGuard)
export class PlaylistsGateway {
  @WebSocketServer()
  server!: Server;

  private readonly logger = new Logger(PlaylistsGateway.name);

  constructor(private readonly playlistsRepository: PlaylistsRepository) {}

  @SubscribeMessage('playlist:join')
  async handlePlaylistJoin(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: PlaylistRoomDto,
    @WsUser() user: SocketUser,
  ) {
    const userId = user.id;
    const playlistId = payload.playlistId;

    const playlist =
      await this.playlistsRepository.findPlaylistForAuth(playlistId);
    if (!playlist) {
      throw new WsException('Playlist not found');
    }

    // Verify Read Access
    if (playlist.visibility === Visibility.PRIVATE) {
      const isOwner = playlist.ownerId === userId;
      const isCollaborator = playlist.collaborators.some(
        (c) => c.userId === userId,
      );
      if (!isOwner && !isCollaborator) {
        throw new WsException('Forbidden: Cannot join private playlist room');
      }
    }

    const roomName = `playlist_${playlistId}`;
    await client.join(roomName);

    this.logger.log(
      `Client ${client.id} (User: ${userId}) joined room ${roomName}`,
    );
    return { event: 'joined', playlistId };
  }

  @SubscribeMessage('playlist:leave')
  async handlePlaylistLeave(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: PlaylistRoomDto,
  ) {
    const roomName = `playlist_${payload.playlistId}`;
    await client.leave(roomName);
    this.logger.log(`Client ${client.id} left room ${roomName}`);
    return { event: 'left', playlistId: payload.playlistId };
  }
}
