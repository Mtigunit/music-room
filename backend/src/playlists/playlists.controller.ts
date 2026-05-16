import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  ParseUUIDPipe,
  Request,
  UseGuards,
  Query,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiParam,
  ApiBody,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { PlaylistsService } from './playlists.service';
import { CreatePlaylistDto } from './dto/create-playlist.dto';
import { UpdatePlaylistDto } from './dto/update-playlist.dto';
import { AddTrackToPlaylistDto } from './dto/add-track-to-playlist.dto';
import { AddCollaboratorDto } from './dto/add-collaborator.dto';
import { ReorderTrackDto } from './dto/reorder-track.dto';
import { PaginationDto } from '../common/dto/pagination.dto';
import { ExplorePlaylistsQueryDto } from './dto/explore-playlists-query.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ClientMeta } from '../common/decorators/client-meta.decorator';
import { ApiClientMeta } from '../common/decorators/api-client-meta.decorator';
import { ClientMetaDto } from '../common/dto/client-meta.dto';

@ApiTags('Playlists')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('playlists')
export class PlaylistsController {
  constructor(private readonly playlistsService: PlaylistsService) {}

  @Post()
  @ApiClientMeta()
  @ApiOperation({ summary: 'Create a new playlist' })
  @ApiBody({ type: CreatePlaylistDto })
  @ApiResponse({ status: 201, description: 'Playlist created.' })
  create(
    @Body() createPlaylistDto: CreatePlaylistDto,
    @Request() req: Express.Request,
    @ClientMeta() meta: ClientMetaDto,
  ) {
    return this.playlistsService.create(req.user!.id, createPlaylistDto, meta);
  }

  @Get()
  @ApiOperation({ summary: 'Get all playlists for the authenticated user' })
  @ApiResponse({
    status: 200,
    description:
      'List of playlists for the authenticated user, including up to 4 tracks for collage generation.',
  })
  findAll(
    @Request() req: Express.Request,
    @Query() paginationDto: PaginationDto,
  ) {
    return this.playlistsService.getUserPlaylists(req.user!.id, paginationDto);
  }

  @Get('explore')
  @ApiOperation({ summary: 'Explore public playlists' })
  @ApiResponse({
    status: 200,
    description:
      'List of public playlists, including up to 4 tracks for collage generation.',
  })
  explorePublicPlaylists(@Query() query: ExplorePlaylistsQueryDto) {
    return this.playlistsService.explorePublicPlaylists(
      query.q,
      query.tag,
      query,
    );
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get a playlist by ID' })
  @ApiParam({ name: 'id', type: String, format: 'uuid' })
  @ApiResponse({ status: 200, description: 'Playlist details.' })
  @ApiResponse({ status: 403, description: 'Forbidden (Private playlist).' })
  @ApiResponse({ status: 404, description: 'Playlist not found.' })
  findOne(
    @Param('id', ParseUUIDPipe) id: string,
    @Request() req: Express.Request,
  ) {
    return this.playlistsService.getPlaylistDetails(id, req.user!.id);
  }

  @Patch(':id')
  @ApiClientMeta()
  @ApiOperation({ summary: 'Update a playlist by ID' })
  @ApiParam({ name: 'id', type: String, format: 'uuid' })
  @ApiBody({ type: UpdatePlaylistDto })
  @ApiResponse({ status: 200, description: 'Playlist updated.' })
  @ApiResponse({ status: 403, description: 'Forbidden (Not the owner).' })
  @ApiResponse({ status: 404, description: 'Playlist not found.' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() updatePlaylistDto: UpdatePlaylistDto,
    @Request() req: Express.Request,
    @ClientMeta() meta: ClientMetaDto,
  ) {
    return this.playlistsService.update(
      id,
      req.user!.id,
      updatePlaylistDto,
      meta,
    );
  }

  @Delete(':id')
  @ApiClientMeta()
  @ApiOperation({ summary: 'Delete a playlist by ID' })
  @ApiParam({ name: 'id', type: String, format: 'uuid' })
  @ApiResponse({ status: 200, description: 'Playlist deleted.' })
  @ApiResponse({ status: 403, description: 'Forbidden (Not the owner).' })
  @ApiResponse({ status: 404, description: 'Playlist not found.' })
  remove(
    @Param('id', ParseUUIDPipe) id: string,
    @Request() req: Express.Request,
    @ClientMeta() meta: ClientMetaDto,
  ) {
    return this.playlistsService.remove(id, req.user!.id, meta);
  }

  @Post(':id/collaborators')
  @ApiClientMeta()
  @ApiOperation({ summary: 'Add a collaborator to a playlist' })
  @ApiParam({ name: 'id', type: String, format: 'uuid' })
  @ApiBody({ type: AddCollaboratorDto })
  @ApiResponse({ status: 201, description: 'Collaborator added.' })
  @ApiResponse({
    status: 400,
    description: 'Bad Request (Target user does not exist).',
  })
  @ApiResponse({ status: 403, description: 'Forbidden (Not the owner).' })
  @ApiResponse({ status: 404, description: 'Playlist not found.' })
  addCollaborator(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() payload: AddCollaboratorDto,
    @Request() req: Express.Request,
    @ClientMeta() meta: ClientMetaDto,
  ) {
    return this.playlistsService.addCollaborator(
      id,
      req.user!.id,
      payload.targetUserId,
      meta,
    );
  }

  @Post(':id/tracks')
  @ApiClientMeta()
  @ApiOperation({ summary: 'Add a track to a playlist' })
  @ApiParam({ name: 'id', type: String, format: 'uuid' })
  @ApiBody({ type: AddTrackToPlaylistDto })
  @ApiResponse({
    status: 201,
    description:
      'Track successfully added to the playlist. Returns the newly generated updated timestamp and the track object.',
    schema: {
      type: 'object',
      properties: {
        newUpdatedAt: { type: 'string', format: 'date-time' },
        track: { type: 'object' },
      },
    },
  })
  @ApiResponse({
    status: 400,
    description: 'Invalid request or Playlist capacity reached.',
  })
  @ApiResponse({ status: 401, description: 'Unauthorized.' })
  @ApiResponse({ status: 403, description: 'Forbidden.' })
  @ApiResponse({
    status: 404,
    description: 'Playlist or Provider Track not found.',
  })
  @ApiResponse({
    status: 409,
    description: 'Track already exists in the playlist.',
  })
  addTrackToPlaylist(
    @Param('id', ParseUUIDPipe) playlistId: string,
    @Body() payload: AddTrackToPlaylistDto,
    @Request() req: Express.Request,
    @ClientMeta() meta: ClientMetaDto,
  ) {
    return this.playlistsService.addTrackToPlaylist(
      playlistId,
      req.user!.id,
      payload.providerTrackId,
      meta,
    );
  }

  @Delete(':id/tracks/:playlistTrackId')
  @ApiClientMeta()
  @ApiOperation({ summary: 'Remove a track from a playlist' })
  @ApiParam({ name: 'id', type: String, format: 'uuid' })
  @ApiParam({ name: 'playlistTrackId', type: String, format: 'uuid' })
  @ApiResponse({
    status: 200,
    description:
      'Track successfully removed. Returns the newly generated updated timestamp, the deleted track, and position updates.',
    schema: {
      type: 'object',
      properties: {
        newUpdatedAt: { type: 'string', format: 'date-time' },
        deletedTrack: { type: 'object' },
        updates: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              trackId: { type: 'string' },
              position: { type: 'number' },
            },
          },
        },
      },
    },
  })
  @ApiResponse({ status: 401, description: 'Unauthorized.' })
  @ApiResponse({
    status: 403,
    description: 'User lacks permission to remove this track.',
  })
  @ApiResponse({ status: 404, description: 'Playlist or Track not found.' })
  removeTrackFromPlaylist(
    @Param('id', ParseUUIDPipe) playlistId: string,
    @Param('playlistTrackId', ParseUUIDPipe) playlistTrackId: string,
    @Request() req: Express.Request,
    @ClientMeta() meta: ClientMetaDto,
  ) {
    return this.playlistsService.removeTrackFromPlaylist(
      playlistId,
      playlistTrackId,
      req.user!.id,
      meta,
    );
  }

  @Patch(':id/tracks/:playlistTrackId/reorder')
  @ApiClientMeta()
  @ApiOperation({ summary: 'Reorder a track in a playlist' })
  @ApiParam({ name: 'id', type: String, format: 'uuid' })
  @ApiParam({ name: 'playlistTrackId', type: String, format: 'uuid' })
  @ApiBody({ type: ReorderTrackDto })
  @ApiResponse({
    status: 200,
    description:
      'Track successfully reordered. Returns the new updated timestamp of the playlist.',
    schema: {
      type: 'object',
      required: ['newUpdatedAt'],
      properties: { newUpdatedAt: { type: 'string', format: 'date-time' } },
    },
  })
  @ApiResponse({ status: 401, description: 'Unauthorized.' })
  @ApiResponse({
    status: 403,
    description: 'User lacks permission to modify this playlist.',
  })
  @ApiResponse({ status: 404, description: 'Playlist or Track not found.' })
  @ApiResponse({
    status: 409,
    description: 'Optimistic Concurrency Control failure. Data is stale.',
  })
  reorderTrack(
    @Param('id', ParseUUIDPipe) playlistId: string,
    @Param('playlistTrackId', ParseUUIDPipe) playlistTrackId: string,
    @Body() payload: ReorderTrackDto,
    @Request() req: Express.Request,
    @ClientMeta() meta: ClientMetaDto,
  ) {
    return this.playlistsService.reorderTrack(
      playlistId,
      playlistTrackId,
      req.user!.id,
      payload,
      meta,
    );
  }
}
