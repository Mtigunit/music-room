import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  ParseIntPipe,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiParam,
  ApiBody,
} from '@nestjs/swagger';
import { PlaylistsService } from './playlists.service';
import { CreatePlaylistDto } from './dto/create-playlist.dto';
import { UpdatePlaylistDto } from './dto/update-playlist.dto';

@ApiTags('Playlists')
@Controller('playlists')
export class PlaylistsController {
  constructor(private readonly playlistsService: PlaylistsService) {}

  @Post()
  @ApiOperation({ summary: 'Create a new playlist' })
  @ApiBody({ type: CreatePlaylistDto })
  @ApiResponse({ status: 201, description: 'Playlist created.' })
  create(@Body() createPlaylistDto: CreatePlaylistDto) {
    return this.playlistsService.create(createPlaylistDto);
  }

  @Get()
  @ApiOperation({ summary: 'Get all playlists' })
  @ApiResponse({ status: 200, description: 'List of playlists.' })
  findAll() {
    return this.playlistsService.findAll();
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get a playlist by ID' })
  @ApiParam({ name: 'id', type: Number })
  @ApiResponse({ status: 200, description: 'Playlist found.' })
  @ApiResponse({ status: 404, description: 'Playlist not found.' })
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.playlistsService.findOne(id);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update a playlist by ID' })
  @ApiParam({ name: 'id', type: Number })
  @ApiBody({ type: UpdatePlaylistDto })
  @ApiResponse({ status: 200, description: 'Playlist updated.' })
  @ApiResponse({ status: 404, description: 'Playlist not found.' })
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() updatePlaylistDto: UpdatePlaylistDto,
  ) {
    return this.playlistsService.update(id, updatePlaylistDto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete a playlist by ID' })
  @ApiParam({ name: 'id', type: Number })
  @ApiResponse({ status: 200, description: 'Playlist deleted.' })
  @ApiResponse({ status: 404, description: 'Playlist not found.' })
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.playlistsService.remove(id);
  }
}
