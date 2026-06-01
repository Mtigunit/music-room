import { IsNotEmpty, IsUUID } from 'class-validator';

export class PlaylistRoomDto {
  @IsUUID()
  @IsNotEmpty()
  playlistId!: string;
}
