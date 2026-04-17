# Track Votes (Example)

This module is a minimal example of a WebSocket feature for voting on a music track.

Event: track:vote
Payload:
- eventId: string
- trackId: string
- vote: "up" | "down" | "none"

Broadcast:
- track:vote:updated
- Emitted to the room with updated totals
