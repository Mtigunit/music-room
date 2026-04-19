import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  ParseUUIDPipe,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  Req,
  Query,
  ParseIntPipe,
  DefaultValuePipe,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiParam,
  ApiBody,
  ApiBearerAuth,
  ApiConsumes,
  ApiQuery,
} from '@nestjs/swagger';
import { FileInterceptor } from '@nestjs/platform-express';
import { EventsService } from './events.service';
import { CreateEventDto } from './dto/create-event.dto';
import { UpdateEventDto } from './dto/update-event.dto';
import { AppendTracksDto } from './dto/append-tracks.dto';
import { InviteUserDto } from './dto/invite-user.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import type { Request } from 'express';

@ApiTags('Events')
@Controller('events')
export class EventsController {
  constructor(private readonly eventsService: EventsService) {}

  @Post()
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @UseInterceptors(FileInterceptor('coverImage'))
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: 'Create a new event' })
  @ApiBody({ type: CreateEventDto })
  @ApiResponse({ status: 201, description: 'Event created.' })
  create(
    @Body() createEventDto: CreateEventDto,
    @Req() req: Request,
    @UploadedFile() file?: Express.Multer.File,
  ) {
    const userId = (req.user as { id: string }).id;
    if (file) createEventDto.coverImage = file.path;
    return this.eventsService.create(userId, createEventDto);
  }

  @Get('explore')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Explore public events and user events' })
  @ApiQuery({
    name: 'page',
    required: false,
    type: Number,
    description: 'Page number (default 1)',
  })
  @ApiQuery({
    name: 'limit',
    required: false,
    type: Number,
    description: 'Items per page (default 10)',
  })
  @ApiQuery({
    name: 'search',
    required: false,
    type: String,
    description: 'Search events by name, tags, or description',
  })
  @ApiResponse({ status: 200, description: 'List of events.' })
  explore(
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('limit', new DefaultValuePipe(10), ParseIntPipe) limit: number,
    @Req() req: Request,
    @Query('search') search?: string,
  ) {
    const userId = (req.user as { id: string }).id;
    return this.eventsService.explore(userId, { page, limit, search });
  }

  @Get()
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get all events created by or invited to the user' })
  @ApiQuery({
    name: 'page',
    required: false,
    type: Number,
    description: 'Page number (default 1)',
  })
  @ApiQuery({
    name: 'limit',
    required: false,
    type: Number,
    description: 'Items per page (default 10)',
  })
  @ApiQuery({
    name: 'search',
    required: false,
    type: String,
    description: 'Search events by name, tags, or description',
  })
  @ApiResponse({ status: 200, description: 'List of user events.' })
  findAll(
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('limit', new DefaultValuePipe(10), ParseIntPipe) limit: number,
    @Req() req: Request,
    @Query('search') search?: string,
  ) {
    const userId = (req.user as { id: string }).id;
    return this.eventsService.findAll(userId, { page, limit, search });
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get an event by ID' })
  @ApiParam({ name: 'id', type: String })
  @ApiResponse({ status: 200, description: 'Event found.' })
  @ApiResponse({ status: 404, description: 'Event not found.' })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.eventsService.findOne(id);
  }

  @Patch(':id')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @UseInterceptors(FileInterceptor('coverImage'))
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: 'Update an event by ID' })
  @ApiParam({ name: 'id', type: String })
  @ApiBody({ type: UpdateEventDto })
  @ApiResponse({ status: 200, description: 'Event updated.' })
  @ApiResponse({ status: 403, description: 'Forbidden.' })
  @ApiResponse({ status: 404, description: 'Event not found.' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() updateEventDto: UpdateEventDto,
    @Req() req: Request,
    @UploadedFile() file?: Express.Multer.File,
  ) {
    const userId = (req.user as { id: string }).id;
    if (file) updateEventDto.coverImage = file.path;
    return this.eventsService.update(id, userId, updateEventDto);
  }

  @Post(':id/tracks')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Append tracks to an event' })
  @ApiParam({ name: 'id', type: String })
  @ApiConsumes('application/json')
  @ApiBody({ type: AppendTracksDto })
  @ApiResponse({ status: 201, description: 'Tracks appended successfully.' })
  @ApiResponse({ status: 403, description: 'Forbidden. No access to event.' })
  @ApiResponse({ status: 404, description: 'Event not found.' })
  appendTracks(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() appendTracksDto: AppendTracksDto,
    @Req() req: Request,
  ) {
    const userId = (req.user as { id: string }).id;
    return this.eventsService.appendTracks(id, userId, appendTracksDto.tracks);
  }

  @Post(':id/invites')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Invite a user to an event' })
  @ApiParam({ name: 'id', type: String })
  @ApiBody({ type: InviteUserDto })
  @ApiResponse({ status: 201, description: 'User invited successfully.' })
  @ApiResponse({
    status: 403,
    description: 'Forbidden. Only the host can invite users.',
  })
  @ApiResponse({ status: 404, description: 'Event or user not found.' })
  @ApiResponse({ status: 409, description: 'User already invited.' })
  inviteUser(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() inviteUserDto: InviteUserDto,
    @Req() req: Request,
  ) {
    const hostId = (req.user as { id: string }).id;
    return this.eventsService.inviteUser(id, hostId, inviteUserDto.userId);
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Delete an event by ID' })
  @ApiParam({ name: 'id', type: String })
  @ApiResponse({ status: 200, description: 'Event deleted.' })
  @ApiResponse({
    status: 403,
    description: 'Forbidden. Only the host can delete this event.',
  })
  @ApiResponse({ status: 404, description: 'Event not found.' })
  remove(@Param('id', ParseUUIDPipe) id: string, @Req() req: Request) {
    const userId = (req.user as { id: string }).id;
    return this.eventsService.remove(id, userId);
  }
}
