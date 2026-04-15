# Track Voting System

## Overview
The Track Voting system allows users to vote "up" or "down" on music tracks within a specific room. The functionality is implemented over WebSockets using Socket.io and leverages Redis to ensure real-time concurrency and atomicity when recording votes across multiple server instances.

## WebSocket Contract

### Event: `track:vote` (Client → Server)
Send a vote for a track in a specific room.

**Payload:**
```json
{
  "roomId": "room-123",
  "trackId": "track-456",
  "vote": "up" // "down" or "none" (to remove a vote)
}
```

**Acknowledgment (Optional):**
If you emit with an acknowledgment function, the server will respond directly to the sender with the updated state:
```json
{
  "roomId": "room-123",
  "trackId": "track-456",
  "upVotes": 5,
  "downVotes": 2,
  "score": 3,
  "updatedAt": "2026-04-15T10:00:00.000Z"
}
```

### Event: `track:vote:updated` (Server → Client)
Any time a vote is recorded, the server broadcasts the new vote state to **all clients currently joined to the room**.

**Payload:**
```json
{
  "roomId": "room-123",
  "trackId": "track-456",
  "upVotes": 5,
  "downVotes": 2,
  "score": 3,
  "updatedAt": "2026-04-15T10:00:00.000Z"
}
```

---

## Testing Locally via `wscat`

Since the backend is using Socket.io (Engine.IO), testing raw WebSockets requires sending the correct framing prefixes.

### 1. Connect to the WebSocket
Make sure your NestJS server is running.
```bash
wscat -c "ws://localhost:3000/ws/?EIO=4&transport=websocket"
```

### 2. Complete the Socket.io Handshake (With Auth Token)
Once connected, you will see a `0{...}` packet from the server. You **must** immediately send back the `40` (CONNECT) packet. 
Because the WebSocket routes are protected by `WsAuthGuard`, you must supply the JWT access token inside this handshake packet.

*Get your JWT token first by using the REST API `/auth/login` endpoint.*

Send the connection packet with your token:
```text
> 40{"token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."}
```
If the token is valid, you will receive `< 40{"sid":"..."}`. If it is invalid, the connection will be dropped or you will receive an error.

### 3. Join a Room
To receive broadcasts about a room, your socket needs to join it first:
```text
> 42["room:join",{"roomId":"room-123"}]
```

### 4. Cast a Vote
Send the `track:vote` event with the required JSON payload. Notice the `42` prefix for an EVENT, followed by a JSON array:
```text
> 42["track:vote",{"roomId":"room-123","trackId":"track-1","vote":"up"}]
```

### 5. Check the Broadcast Result
If successful, you will immediately see the server broadcast the `track:vote:updated` event back to your terminal (since you joined `room-123` in step 3):
```text
< 42["track:vote:updated",{"roomId":"room-123","trackId":"track-1","upVotes":1,"downVotes":0,"score":1,"updatedAt":"2026-04-15T..."}]
```
