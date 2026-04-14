import { Injectable, OnModuleInit, Logger } from '@nestjs/common';
import { EventRegistryService } from '../websockets/event-registry.service';
import { WSContext } from '../websockets/interfaces/websocket.interface';

@Injectable()
export class VotesService implements OnModuleInit {
  private readonly logger = new Logger(VotesService.name);

  constructor(private readonly eventRegistry: EventRegistryService) {}

  onModuleInit() {
    // Register the event handler when the module is initialized
    this.eventRegistry.register('vote:cast', this.handleCastVote.bind(this));
  }

  private async handleCastVote(ctx: WSContext, payload: any) {
    const { trackId, type } = payload as {
      trackId: string;
      type: 'up' | 'down';
    };

    if (!trackId || !type) {
      this.logger.warn('Invalid vote payload received');
      // Send error back to the user who sent it
      if (ctx.ws.readyState === ctx.ws.OPEN) {
        ctx.ws.send(
          JSON.stringify({ event: 'error', payload: 'Invalid vote payload' }),
        );
      }
      return;
    }

    this.logger.log(`User ${ctx.userId} voted ${type} on track ${trackId}`);

    // Atomic Redis increment using the injected client from ctx
    // We increment the specific 'up' or 'down' counter
    // await ctx.redisClient.hincrby(`track:${trackId}:votes`, type, 1);

    // Calculate a total score if you want (optional)
    const increment = type === 'up' ? 1 : -1;
    await ctx.redisClient.hincrby(`track:${trackId}:votes`, 'score', increment);

    // Broadcast the update to everyone in the same room
    if (ctx.roomId) {
      ctx.broadcast(ctx.roomId, {
        event: 'vote:updated',
        payload: { trackId, type },
      });
    }
  }
}
