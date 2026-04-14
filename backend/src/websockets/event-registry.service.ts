import { Injectable, Logger } from '@nestjs/common';
import {
  EventHandler,
  WSContext,
  WSMessage,
} from './interfaces/websocket.interface';

@Injectable()
export class EventRegistryService {
  private readonly logger = new Logger(EventRegistryService.name);
  private readonly handlers = new Map<string, EventHandler>();

  // Register a handler for an event
  register(event: string, handler: EventHandler): void {
    if (this.handlers.has(event)) {
      this.logger.warn(
        `Handler for event [${event}] is already registered. Overwriting.`,
      );
    }
    this.handlers.set(event, handler);
    this.logger.log(`Registered WS handler for event: ${event}`);
  }

  // Dispatch incoming message to the right handler
  async dispatch(ctx: WSContext, message: WSMessage): Promise<void> {
    const handler = this.handlers.get(message.event);

    if (!handler) {
      this.logger.warn(`No handler registered for event: ${message.event}`);
      return;
    }

    try {
      await handler(ctx, message.payload);
    } catch (err: any) {
      this.logger.error(
        `Error handling event [${message.event}]:`,
        err instanceof Error ? err.stack : String(err),
      );
      // Send error back to the connected client
      if (ctx.ws.readyState === ctx.ws.OPEN) {
        ctx.ws.send(
          JSON.stringify({
            event: 'error',
            payload:
              err instanceof Error ? err.message : 'Internal Server Error',
          }),
        );
      }
    }
  }
}
