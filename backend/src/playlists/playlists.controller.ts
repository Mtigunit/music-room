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
  ApiQuery,
} from '@nestjs/swagger';
import { PlaylistsService } from './playlists.service';
import { CreatePlaylistDto } from './dto/create-playlist.dto';
import { UpdatePlaylistDto } from './dto/update-playlist.dto';
import { AddTrackToPlaylistDto } from './dto/add-track-to-playlist.dto';
import { AddCollaboratorDto } from './dto/add-collaborator.dto';
import { PaginationDto } from '../common/dto/pagination.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@ApiTags('Playlists')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('playlists')
export class PlaylistsController {
  constructor(private readonly playlistsService: PlaylistsService) {}

  @Post()
  @ApiOperation({ summary: 'Create a new playlist' })
  @ApiBody({ type: CreatePlaylistDto })
  @ApiResponse({ status: 201, description: 'Playlist created.' })
  create(
    @Body() createPlaylistDto: CreatePlaylistDto,
    @Request() req: Express.Request,
  ) {
    return this.playlistsService.create(req.user!.id, createPlaylistDto);
  }

  @Get()
  @ApiOperation({ summary: 'Get all playlists for the authenticated user' })
  @ApiResponse({ status: 200, description: 'List of playlists.' })
  findAll(
    @Request() req: Express.Request,
    @Query() paginationDto: PaginationDto,
  ) {
    return this.playlistsService.getUserPlaylists(req.user!.id, paginationDto);
  }

  @Get('explore')
  @ApiOperation({ summary: 'Explore public playlists' })
  @ApiQuery({
    name: 'q',
    required: false,
    description: 'Search name or description',
  })
  @ApiQuery({
    name: 'tag',
    required: false,
    description: 'Filter by genre/tag',
  })
  @ApiResponse({ status: 200, description: 'List of public playlists.' })
  explorePublicPlaylists(
    @Query('q') searchQuery: string,
    @Query('tag') tag: string,
    @Query() paginationDto: PaginationDto,
  ) {
    return this.playlistsService.explorePublicPlaylists(
      searchQuery,
      tag,
      paginationDto,
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
  ) {
    return this.playlistsService.update(id, req.user!.id, updatePlaylistDto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete a playlist by ID' })
  @ApiParam({ name: 'id', type: String, format: 'uuid' })
  @ApiResponse({ status: 200, description: 'Playlist deleted.' })
  @ApiResponse({ status: 403, description: 'Forbidden (Not the owner).' })
  @ApiResponse({ status: 404, description: 'Playlist not found.' })
  remove(
    @Param('id', ParseUUIDPipe) id: string,
    @Request() req: Express.Request,
  ) {
    return this.playlistsService.remove(id, req.user!.id);
  }

  @Post(':id/collaborators')
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
  ) {
    return this.playlistsService.addCollaborator(
      id,
      req.user!.id,
      payload.targetUserId,
    );
  }

  @Post(':id/tracks')
  @ApiOperation({ summary: 'Add a track to a playlist' })
  @ApiParam({ name: 'id', type: String, format: 'uuid' })
  @ApiBody({ type: AddTrackToPlaylistDto })
  @ApiResponse({ status: 201, description: 'Track added to playlist.' })
  @ApiResponse({ status: 400, description: 'Invalid request.' })
  @ApiResponse({ status: 401, description: 'Unauthorized.' })
  addTrackToPlaylist(
    @Param('id', ParseUUIDPipe) playlistId: string,
    @Body() payload: AddTrackToPlaylistDto,
    @Request() req: Express.Request,
  ) {
    return this.playlistsService.addTrackToPlaylist(
      playlistId,
      req.user!.id,
      payload.track,
    );
  }
}
