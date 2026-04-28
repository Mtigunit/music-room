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
import { InviteUserDto } from './dto/invite-user.dto';
import { AppendedTrackDto } from './dto/append-tracks.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ClientMeta } from '../common/decorators/client-meta.decorator';
import { ClientMetaDto } from '../common/dto/client-meta.dto';
import { ApiClientMeta } from '../common/decorators/api-client-meta.decorator';
import type { Request } from 'express';

@ApiTags('Events')
@Controller('events')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class EventsController {
  constructor(private readonly eventsService: EventsService) {}

  @Post()
  @UseInterceptors(FileInterceptor('coverImage'))
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: 'Create a new event' })
  @ApiClientMeta()
  @ApiBody({ type: CreateEventDto })
  @ApiResponse({ status: 201, description: 'Event created.' })
  create(
    @Body() createEventDto: CreateEventDto,
    @Req() req: Request,
    @ClientMeta() meta: ClientMetaDto,
    @UploadedFile() file?: Express.Multer.File,
  ) {
    const userId = (req.user as { id: string }).id;
    if (file) createEventDto.coverImage = file.path;
    return this.eventsService.create(userId, createEventDto, meta);
  }

  @Get()
  @ApiOperation({ summary: 'Get all public events' })
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
  @ApiResponse({ status: 200, description: 'List of public events.' })
  findAll(
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('limit', new DefaultValuePipe(10), ParseIntPipe) limit: number,
    @Req() req: Request,
    @Query('search') search?: string,
  ) {
    const userId = (req.user as { id: string }).id;
    return this.eventsService.findAll(userId, { page, limit, search });
  }

  @Get('hosting')
  @ApiOperation({ summary: 'Get all events created by that user' })
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
  @ApiResponse({
    status: 200,
    description: 'List of events hosted by the user.',
  })
  findHosting(
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('limit', new DefaultValuePipe(10), ParseIntPipe) limit: number,
    @Req() req: Request,
    @Query('search') search?: string,
  ) {
    const userId = (req.user as { id: string }).id;
    return this.eventsService.findHosting(userId, { page, limit, search });
  }

  @Get('invited')
  @ApiOperation({ summary: 'Get all events that the user was invited to' })
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
  @ApiResponse({
    status: 200,
    description: 'List of events the user is invited to.',
  })
  findInvited(
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('limit', new DefaultValuePipe(10), ParseIntPipe) limit: number,
    @Req() req: Request,
    @Query('search') search?: string,
  ) {
    const userId = (req.user as { id: string }).id;
    return this.eventsService.findInvited(userId, { page, limit, search });
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get an event by ID' })
  @ApiParam({ name: 'id', type: String })
  @ApiResponse({ status: 200, description: 'Event found.' })
  @ApiResponse({ status: 403, description: 'Forbidden. No access to event.' })
  @ApiResponse({ status: 404, description: 'Event not found.' })
  findOne(@Param('id', ParseUUIDPipe) id: string, @Req() req: Request) {
    const userId = (req.user as { id: string }).id;
    return this.eventsService.findOne(id, userId);
  }

  @Patch(':id')
  @UseInterceptors(FileInterceptor('coverImage'))
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: 'Update an event by ID' })
  @ApiClientMeta()
  @ApiParam({ name: 'id', type: String })
  @ApiBody({ type: UpdateEventDto })
  @ApiResponse({ status: 200, description: 'Event updated.' })
  @ApiResponse({ status: 403, description: 'Forbidden.' })
  @ApiResponse({ status: 404, description: 'Event not found.' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() updateEventDto: UpdateEventDto,
    @Req() req: Request,
    @ClientMeta() meta: ClientMetaDto,
    @UploadedFile() file?: Express.Multer.File,
  ) {
    const userId = (req.user as { id: string }).id;
    if (file) updateEventDto.coverImage = file.path;
    return this.eventsService.update(id, userId, updateEventDto, meta);
  }

  @Post(':id/invites')
  @ApiOperation({ summary: 'Invite a user to an event' })
  @ApiClientMeta()
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
    @ClientMeta() meta: ClientMetaDto,
  ) {
    const hostId = (req.user as { id: string }).id;
    return this.eventsService.inviteUser(
      id,
      hostId,
      inviteUserDto.userId,
      meta,
    );
  }

  @Get(':id/tracks')
  @ApiOperation({ summary: 'Get tracks of an event' })
  @ApiParam({ name: 'id', type: String })
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
  @ApiResponse({ status: 200, description: 'Event tracks retrieved.' })
  @ApiResponse({ status: 403, description: 'Forbidden. No access to event.' })
  @ApiResponse({ status: 404, description: 'Event not found.' })
  getTracks(
    @Param('id', ParseUUIDPipe) id: string,
    @Req() req: Request,
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('limit', new DefaultValuePipe(10), ParseIntPipe) limit: number,
  ) {
    const userId = (req.user as { id: string }).id;
    return this.eventsService.getTracks(id, userId, { page, limit });
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete an event by ID' })
  @ApiClientMeta()
  @ApiParam({ name: 'id', type: String })
  @ApiResponse({ status: 200, description: 'Event deleted.' })
  @ApiResponse({
    status: 403,
    description: 'Forbidden. Only the host can delete this event.',
  })
  @ApiResponse({ status: 404, description: 'Event not found.' })
  remove(
    @Param('id', ParseUUIDPipe) id: string,
    @Req() req: Request,
    @ClientMeta() meta: ClientMetaDto,
  ) {
    const userId = (req.user as { id: string }).id;
    return this.eventsService.remove(id, userId, meta);
  }

  @Post(':eventId/tracks')
  @ApiOperation({ summary: 'Append a track to an event' })
  @ApiClientMeta()
  @ApiParam({ name: 'eventId', type: String })
  @ApiBody({ type: AppendedTrackDto })
  @ApiResponse({ status: 201, description: 'Track added successfully.' })
  @ApiResponse({ status: 403, description: 'Forbidden.' })
  @ApiResponse({ status: 404, description: 'Event not found.' })
  appendTrack(
    @Param('eventId', ParseUUIDPipe) eventId: string,
    @Body() appendedTrackDto: AppendedTrackDto,
    @Req() req: Request,
    @ClientMeta() meta: ClientMetaDto,
  ) {
    const userId = (req.user as { id: string }).id;
    return this.eventsService.appendTrack(
      eventId,
      userId,
      appendedTrackDto.providerTrackId,
      meta,
    );
  }

  @Delete(':eventId/tracks/:providerTrackId')
  @ApiOperation({ summary: 'Remove a track from an event by provider ID' })
  @ApiClientMeta()
  @ApiParam({ name: 'eventId', type: String })
  @ApiParam({ name: 'providerTrackId', type: String })
  @ApiResponse({ status: 200, description: 'Track removed successfully.' })
  @ApiResponse({ status: 403, description: 'Forbidden.' })
  @ApiResponse({ status: 404, description: 'Event or Track not found.' })
  removeTrack(
    @Param('eventId', ParseUUIDPipe) eventId: string,
    @Param('providerTrackId') providerTrackId: string,
    @Req() req: Request,
    @ClientMeta() meta: ClientMetaDto,
  ) {
    const userId = (req.user as { id: string }).id;
    return this.eventsService.removeTrack(
      eventId,
      providerTrackId,
      userId,
      meta,
    );
  }
}
