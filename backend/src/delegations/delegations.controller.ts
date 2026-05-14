import {
  Controller,
  Post,
  Delete,
  Get,
  Body,
  Param,
  ParseUUIDPipe,
  Req,
  UseGuards,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiParam,
  ApiBody,
} from '@nestjs/swagger';
import { DelegationsService } from './delegations.service';
import { GrantDelegationDto } from './dto/grant-delegation.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ClientMeta } from '../common/decorators/client-meta.decorator';
import { ClientMetaDto } from '../common/dto/client-meta.dto';
import type { Request } from 'express';

@ApiTags('Delegations')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('events/:id/delegations')
export class DelegationsController {
  constructor(private readonly delegationsService: DelegationsService) {}

  @Post()
  @ApiOperation({ summary: 'Grant music control delegation to a friend' })
  @ApiParam({ name: 'id', type: String, description: 'Event ID' })
  @ApiBody({ type: GrantDelegationDto })
  @ApiResponse({ status: 201, description: 'Delegation granted.' })
  @ApiResponse({ status: 403, description: 'Only host can grant delegation.' })
  @ApiResponse({ status: 404, description: 'Event or user not found.' })
  grant(
    @Param('id', ParseUUIDPipe) eventId: string,
    @Body() dto: GrantDelegationDto,
    @Req() req: Request,
    @ClientMeta() meta: ClientMetaDto,
  ) {
    const hostId = (req.user as { id: string }).id;
    return this.delegationsService.grant(
      eventId,
      hostId,
      dto.delegateeId,
      meta,
    );
  }

  @Delete(':delegateeId')
  @ApiOperation({ summary: 'Revoke music control delegation from a friend' })
  @ApiParam({ name: 'id', type: String, description: 'Event ID' })
  @ApiParam({
    name: 'delegateeId',
    type: String,
    description: 'Delegatee user ID',
  })
  @ApiResponse({ status: 200, description: 'Delegation revoked.' })
  @ApiResponse({ status: 403, description: 'Only host can revoke delegation.' })
  revoke(
    @Param('id', ParseUUIDPipe) eventId: string,
    @Param('delegateeId', ParseUUIDPipe) delegateeId: string,
    @Req() req: Request,
    @ClientMeta() meta: ClientMetaDto,
  ) {
    const hostId = (req.user as { id: string }).id;
    return this.delegationsService.revoke(eventId, hostId, delegateeId, meta);
  }

  @Get()
  @ApiOperation({ summary: 'List active delegations for an event' })
  @ApiParam({ name: 'id', type: String, description: 'Event ID' })
  @ApiResponse({ status: 200, description: 'List of active delegations.' })
  @ApiResponse({ status: 403, description: 'Only host can list delegations.' })
  list(@Param('id', ParseUUIDPipe) eventId: string, @Req() req: Request) {
    const hostId = (req.user as { id: string }).id;
    return this.delegationsService.list(eventId, hostId);
  }
}
