import {
  Controller,
  Get,
  Patch,
  Param,
  ParseUUIDPipe,
  Query,
  Request,
  UseGuards,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiParam,
} from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { NotificationsService } from './notifications.service';
import { NotificationsQueryDto } from './dto/notification-query.dto';
import { ClientMeta } from '../common/decorators/client-meta.decorator';
import type { ClientMetaDto } from '../common/dto/client-meta.dto';

@ApiTags('Notifications')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Get()
  @ApiOperation({ summary: 'Get a list of notifications for the current user' })
  @ApiResponse({ status: 200, description: 'List of notifications.' })
  async getNotifications(
    @Request() req: Express.Request,
    @Query() query: NotificationsQueryDto,
    @ClientMeta() meta: ClientMetaDto,
  ) {
    return this.notificationsService.getNotifications(
      req.user!.id,
      query,
      meta,
    );
  }

  @Patch(':id/read')
  @ApiOperation({ summary: 'Mark a notification as read' })
  @ApiParam({ name: 'id', type: 'string', format: 'uuid' })
  @ApiResponse({ status: 200, description: 'Notification marked as read.' })
  @ApiResponse({ status: 404, description: 'Notification not found.' })
  async markAsRead(
    @Request() req: Express.Request,
    @Param('id', ParseUUIDPipe) id: string,
    @ClientMeta() meta: ClientMetaDto,
  ) {
    const data = await this.notificationsService.markAsRead(
      req.user!.id,
      id,
      meta,
    );
    return { success: true, data };
  }
}
