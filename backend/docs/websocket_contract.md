# WebSocket (Socket.io) Contract

This document describes the **current Socket.io event contract** exposed by the backend.

> Note: WebSocket gateways don’t appear in Swagger REST docs. This file is the canonical reference for WS events.

## Connection

- **Endpoint (HTTP base):** same host/port as the REST API (for example `http://localhost:3000`)
- **Socket.io path:** `/ws`
- **Recommended transport:** `websocket`

### Authentication (required)

Clients must authenticate **during the Socket.io handshake** by providing a JWT in `auth.token`.

- If the token is invalid/expired, or the user no longer exists, the server rejects the connection.
- On the client, this surfaces as `connect_error` (typically with `err.message === "unauthorized"`).

#### JS example

```js
import { io } from 'socket.io-client';

const socket = io('http://localhost:3000', {
  path: '/ws',
  transports: ['websocket'],
  auth: { token: process.env.WS_TOKEN },
});

socket.on('connect_error', (err) => {
  console.error('connect_error:', err.message);
});
```

## Rooms

Rooms are treated as **opaque strings** (for example, an event ID). Clients can join/leave rooms to scope broadcasts.

## Event Contract

Conventions used below:

- **Client → Server**: event emitted by the client.
- **Server → Client**: event emitted by the server.
- **Ack**: Socket.io acknowledgement callback. If the client provides a callback, the server may respond with a single payload.

### `room:join`

- **Client → Server**: `room:join`
- **Payload**: `{ roomId: string }`
- **Server → Client (success)**: `room:joined` `{ roomId: string }`
- **Server → Client (error)**: `room:error` `{ message: string }` when `roomId` is missing/blank

### `room:leave`

- **Client → Server**: `room:leave`
- **Payload**: `{ roomId: string }`
- **Server → Client (success)**: `room:left` `{ roomId: string }`
- **Server → Client (error)**: `room:error` `{ message: string }` when `roomId` is missing/blank

### `ping`

- **Client → Server**: `ping`
- **Payload**: none
- **Server → Client**: `pong` `{ serverTime: string }` (ISO timestamp)

### `track:vote` (example feature)

This is an example “feature gateway” that demonstrates validated payloads, returning an ack, and broadcasting to a room.

- **Client → Server**: `track:vote`
- **Payload**:
  - `{ roomId: string, trackId: string, vote: "up" | "down" }`
- **Ack (server response)**: `{ roomId, trackId, upVotes, downVotes, score, updatedAt }`
  - The client receives this **only if** it provides an acknowledgement callback.
- **Server → Client (broadcast)**: `track:vote:updated` `{ roomId, trackId, upVotes, downVotes, score, updatedAt }`
  - Broadcasted to everyone in `roomId`.

### Playlists (`PlaylistsGateway`)

The playlists gateway handles real-time updates for collaborative playlist editing (Phase 1).

> **Note on Data Integrity:** The backend enforces track uniqueness per playlist at the database level. Any operation that violates this (e.g., adding a duplicate track) will return a `409 Conflict` error.

#### `playlist:join`

- **Client → Server**: `playlist:join`
- **Payload**: `{ playlistId: string }`
- **Server Verification**: Verifies the playlist exists and the user has visibility/collaboration rights.
- **Server → Client (success ack)**: `{ event: 'joined', playlistId }`
- **Server → Client (error)**: Throws `WsException` if missing ID, playlist not found, or user is forbidden.

#### `playlist:leave`

- **Client → Server**: `playlist:leave`
- **Payload**: `{ playlistId: string }`
- **Server → Client (success ack)**: `{ event: 'left', playlistId }`

#### `playlist:track:added`

Broadcasted immediately after a new track is added to the playlist via the REST API (`POST /playlists/:id/tracks`).
- **Server → Client (broadcast)**: `playlist:track:added`
- **Payload**: A full `PlaylistTrack` object including nested `track` dictionary data and `position`.

#### `playlist:track:removed`

Broadcasted immediately after a track is removed via the REST API (`DELETE /playlists/:id/tracks/:playlistTrackId`).
- **Server → Client (broadcast)**: `playlist:track:removed`
- **Payload**:
  ```json
  {
    "playlistId": "string",
    "deletedTrackId": "string",
    "updates": [
      { "trackId": "string", "position": number }
    ]
  }
  ```
- **Note**: `deletedTrackId` is the removed `PlaylistTrack.id`. `updates` contains the new absolute positions for all tracks that were shifted down to fill the gap.

#### `playlist:track:reordered`

Broadcasted immediately after a track is reordered via the REST API (`PATCH /playlists/:id/tracks/:playlistTrackId/reorder`).
- **Server → Client (broadcast)**: `playlist:track:reordered`
- **Payload**:
  ```json
  {
    "playlistId": "string",
    "updates": [
      { "trackId": "string", "position": number }
    ]
  }
  ```
- **Note**: `updates` contains the exact absolute mathematical positions for all tracks that had to move to accommodate the slide operation, including the actively dragged track!

## Errors & Disconnects

### Handshake rejection

If authentication fails during the handshake, the client will get:

- `connect_error` with an error message (commonly `"unauthorized"`).

### Room validation

If `roomId` is missing/blank for join/leave:

- `room:error` `{ message: string }`

### Data Integrity Conflicts

If an operation (such as adding a track) violates a database constraint (e.g., duplicate track in a playlist):

- **Status Code**: `409 Conflict`
- **WS Behavior**: Throws a `WsException` which is caught by the global filter and returned as an error event if categorized as such, or handled via REST if initiated there.

## Smoke Test

There is a small Node smoke test client:

- `backend/scripts/ws-smoke-test.js`
- Run from `backend/`: `npm run ws:smoke`
- Requires `WS_TOKEN` to be set for authenticated handshake.

### Multi-instance (Redis adapter) smoke test

To validate the Redis pub/sub adapter, you must run **two backend instances** connected to the **same Redis** (different ports), then run:

- `backend/scripts/ws-multi-instance-test.js`
- Run from `backend/`: `npm run ws:multi`

Environment variables:

- `WS_TOKEN` (required)
- `WS_HOST_A` (default: `http://localhost:3000`)
- `WS_HOST_B` (default: `http://localhost:3001`)
- `WS_PATH` (default: `/ws`)
- `WS_ROOM`, `WS_TRACK`, `WS_VOTE`
- `WS_TIMEOUT_MS` (default: `8000`)
