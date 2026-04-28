# Real-Time Playback Synchronization Plan

This document outlines the approach for managing the "Currently Playing Track" state, answering your questions regarding database storage and real-time synchronization.

## Do we need to store it in the DB?

**Yes, absolutely.**

According to your `spec.md` and the current `schema.prisma`, the backend must act as the **authoritative source of truth**. You already have the required fields in the `Event` model:
- `playbackStatus` (STOPPED, PLAYING, PAUSED)
- `currentTrackStartedAt` (DateTime)
- `pausedPlaybackPositionMs` (Int)
- `currentTrackId` (String)

**Why keep it in the DB?**
1. **Late Joiners:** When a new user joins a live event, they need to know exactly what is playing and at what second the song is at. They fetch this initial state from the DB via the REST API.
2. **Host Disconnection:** If the Host's app crashes or disconnects from WebSockets, the event doesn't lose its state. When the Host reconnects, they read `currentTrackStartedAt` from the DB and resume seamlessly.
3. **Progress Bar Sync (FR-E02):** Guests don't stream audio. They use `currentTrackStartedAt` to calculate the progress bar locally.

---

## How to send real-time data to the Frontend?

We will use the existing `events.gateway.ts` (Socket.io) to broadcast state changes to the specific event room (`event_${eventId}`).

### The Architecture / Data Flow

#### 1. Host Triggers Playback Change
The Host (or a Delegated user) presses Play, Pause, or Skip. The frontend sends an authenticated request to the backend.
*(I recommend using REST API endpoints like `POST /events/:id/playback/play` for these commands so they can be easily protected by standard guards and return proper HTTP error codes, but we can also use WebSocket messages if you prefer).*

#### 2. Backend Updates Database
The backend service (e.g., `EventsService` or a new `PlaybackService`) will update the `Event` record:
- **Play:** Set `playbackStatus = PLAYING`.
  - If it's a new track: Set `currentTrackId`, set `currentTrackStartedAt = now()`, set `pausedPlaybackPositionMs = 0`.
  - If resuming: Calculate `currentTrackStartedAt = now() - pausedPlaybackPositionMs`.
- **Pause:** Set `playbackStatus = PAUSED`. Calculate `pausedPlaybackPositionMs = now() - currentTrackStartedAt`. Set `currentTrackStartedAt = null`.
- **Skip/Next:** Mark current `EventTrack` status as `PLAYED`. Set `currentTrackId` to the next track (based on `voteScore`). Update timestamps.

#### 3. Backend Broadcasts Real-Time Event
Immediately after the DB transaction succeeds, the backend emits a WebSocket event to the room:

```typescript
// Example payload structure
this.eventsGateway.server.to(`event_${eventId}`).emit('playback:sync', {
  eventId,
  currentTrackId: "track-123",
  playbackStatus: "PLAYING", // or PAUSED, STOPPED
  currentTrackStartedAt: "2026-04-25T14:10:00.000Z", // Server Timestamp
  pausedPlaybackPositionMs: 0
});
```

#### 4. Frontend (Flutter) Syncs
- All clients (Host and Guests) listen for `playback:sync`.
- When received, the UI updates the currently playing track details.
- To render the **Progress Bar**: The Flutter app calculates the current playback position locally using `DateTime.now().difference(currentTrackStartedAt)`. Since the server timestamp acts as the anchor, everyone's progress bar stays in sync without continuous heavy WebSocket traffic.

---

## User Review Required

> [!IMPORTANT]  
> Please review the architecture above. 
> 
> **Decision Point:** Do you prefer to handle the Host's commands (Play, Pause, Skip) via **REST API Endpoints** (e.g., `POST /events/:id/playback/play`) or via **WebSocket messages** (e.g., `@SubscribeMessage('playback:play')`)? 
> 
> REST is usually better for strict transactional database updates and error handling (403, 404), while WebSockets are purely used for *broadcasting* the result to everyone.

Once you confirm, we can proceed to implement the `Playback` logic in the backend!
