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

## Errors & Disconnects

### Handshake rejection

If authentication fails during the handshake, the client will get:

- `connect_error` with an error message (commonly `"unauthorized"`).

### Room validation

If `roomId` is missing/blank for join/leave:

- `room:error` `{ message: string }`

## Smoke Test

There is a small Node smoke test client:

- `backend/scripts/ws-smoke-test.js`
- Run from `backend/`: `npm run ws:smoke`
- Requires `WS_TOKEN` to be set for authenticated handshake.
