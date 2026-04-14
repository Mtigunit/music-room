# Generic Event-Driven WebSocket Architecture

## 📖 Overview

In the `Music Room` project, we need a WebSocket system that can handle much more than just a single feature (like chat). We need it to handle track voting, managing the music queue, user presence, and more as the app grows.

Instead of writing a massive Gateway file with dozens of `@SubscribeMessage()` decorators connected to different domains, we structured our WebSocket layer using a **Generic Event Registry** pattern. This separates the logic completely and enables highly scalable atomic operations directly against Redis.

---

## 🏛 Architecture Breakdown

### 1. `GenericWebsocketGateway` (The Entrypoint)
*Located in: `src/websockets/generic-websocket.gateway.ts`*

**Role:** This acts as the "front door" for all WebSocket connections.
**Why we did it this way:** 
- Instead of handling specific events (like `vote:cast` or `chat:send`) at the Gateway level, it passes **all** incoming messages into an `EventRegistryService`.
- **In-Memory Room Tracking:** We store the local TCP sockets in a `Map<string, Set<WebSocket>>` so we can easily broadcast payloads to anyone connected to `"room-123"` without hitting a database.
- **Context Injection:** When a payload arrives, it wraps the raw WebSocket, the authentic `userId`, the current `roomId`, an active connection to **Redis (`ioredis`)**, and a `broadcast()` helper into a `WSContext` object before passing it along.

### 2. `EventRegistryService` (The Router)
*Located in: `src/websockets/event-registry.service.ts`*

**Role:** A centralized Map that maps a string (e.g. `"vote:cast"`) to a specific TypeScript function. 
**Why we did it this way:**
- **Decoupling Domains:** If the "Playlists" team wants to add a `"queue:add"` event, they don't have to touch the WebSocket Gateway file at all. They just inject the `EventRegistryService` into their own service and run `.register('queue:add', myFunc)`.
- It safely catches errors parsing invalid payloads and prevents an exploding handler from taking down the entire web socket server.

### 3. `WSContext` & `WSMessage` (The Contract)
*Located in: `src/websockets/interfaces/websocket.interface.ts`*

**Role:** Defines the standard expected envelope for any message.
**Why we did it this way:**
- **Consistency:** Clients know they must **always** send `{ "event": string, "roomId": string, "payload": {} }`.
- **Power in Handlers:** Because `ctx.redisClient` is injected into every event handler organically, developers can perform lightning-fast `.hincrby` or `.sadd` atomic operations directly in their domain files.

---

## 🧱 Real World Example: The Voting System

We implemented a test using `VotesModule` (`src/votes/votes.service.ts`).

### How a Vote travels through the system:
1. The frontend client (`ws-test.html`) opens a connection to `ws://api.url/ws?userId=user-1`.
2. The user clicks "Upvote", sending:
   ```json
   {
      "event": "vote:cast",
      "roomId": "party-123",
      "payload": {
         "trackId": "track-999",
         "type": "up"
      }
   }
   ```
3. `GenericWebsocketGateway` parses the JSON, attaches the Redis client, and throws it to `EventRegistryService.dispatch()`.
4. `EventRegistryService` matches `"vote:cast"` and routes it to `handleCastVote()` inside `VotesService`.
5. `VotesService` atomically executes `ctx.redisClient.hincrby('track:track-999:votes', 'score', 1)`.
6. Finally, `VotesService` calls `ctx.broadcast(ctx.roomId, {...})` to instantly alert the other users in the room that the track score has increased!

---

## ⚡ Cross-Server Scaling with Redis Pub/Sub & Presence Tracking

### 1. Global Presence Tracking (State)
When a user joins a room on *any* server instance, that instance performs a Redis Set Add:
```redis
SADD room:123:users "user-1"
```
When they disconnect, we run `SREM room:123:users "user-1"`. 

This means that *any* backend service can simply query `SMEMBERS room:123:users` to reliably get the exact list of everyone active in the room across all servers.

### 2. Distributed Broadcasting (Pub/Sub)
We replaced the local-only `broadcast()` function with a distributed model using `ioredis` duplicates for Pub/Sub.

When `VotesService` calls `ctx.broadcast('party-123', eventData)`:
1. The WebSocket Gateway publishes the payload to a global Redis channel named `"ws-broadcast"`.
2. ALL active backend instances (Server A, B, C...) are subscribed to `"ws-broadcast"`.
3. They instantly receive the payload, look into their **local RAM `Map`** to see if they hold any open TCP sockets for `"party-123"`, and if so, forward the bits exactly to those specific connected clients in real-time.

This hybrid approach ensures lightning-fast delivery (RAM) perfectly synced across an infinitely scaled containerized backend (Redis Pub/Sub).
