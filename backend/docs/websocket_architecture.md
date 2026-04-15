# Socket.io WebSocket Architecture

## Overview

The WebSocket layer is implemented using Socket.io to keep the setup minimal and reliable for mobile and multi-instance deployments. This provides room management, automatic reconnection on the client, and a supported Redis adapter for cross-node broadcasts.

## Core Components

### 1) Socket.io Gateway

- File: `src/websockets/socket-io.gateway.ts`
- Responsibilities:
  - Accept connections and log lifecycle events.
  - Require a JWT handshake token in `auth.token`.
  - Handle `room:join` and `room:leave` events.
  - Provide a simple `ping`/`pong` health check for smoke testing.

### 2) Redis Adapter

- File: `src/websockets/socket-io.adapter.ts`
- Uses `@socket.io/redis-adapter` with the `redis` v4 client.
- Enables broadcasting to rooms across multiple server instances.

## Event Contract

The canonical contract for clients is documented in: `docs/websocket_contract.md`.

This setup uses native Socket.io events (no envelope). Clients must connect with
`auth.token` set to a valid JWT. The server validates the JWT and checks that the
user exists in the database during the Socket.io handshake. If validation fails,
the connection is rejected (client receives a `connect_error`).

Events currently supported:

- `room:join` -> `{ roomId: string }`
- `room:leave` -> `{ roomId: string }`
- `ping` -> server emits `pong` with a timestamp
- `track:vote` -> `{ roomId: string, trackId: string, vote: "up" | "down" }`
- `track:vote:updated` -> `{ roomId, trackId, upVotes, downVotes, score, updatedAt }`

## Smoke Test Client

A Node-based client script is provided:

- File: `scripts/ws-smoke-test.js`
- Run: `npm run ws:smoke`
- Environment variables:
  - `WS_HOST` (default: `http://localhost:3000`)
  - `WS_PATH` (default: `/ws`)
  - `WS_ROOM` (default: `room-123`)
  - `WS_TRACK` (default: `track-456`)
  - `WS_VOTE` (default: `up`)
  - `WS_TOKEN` (JWT for socket auth)

## Future Extensions

Feature teams can add new handlers directly on the gateway or create additional gateways. The shared setup ensures rooms and broadcasts work consistently across instances.
