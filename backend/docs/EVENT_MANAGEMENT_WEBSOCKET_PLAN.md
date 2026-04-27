# Event Management — WebSocket Implementation Plan

## Overview

This document outlines the architecture and approach for the event management feature in the `music-room` project. It covers how users join events, how hosts start and end events, how disconnections are handled gracefully, and the reasoning behind every technical decision.

---

## Infrastructure Recap

The WebSocket layer is built on Socket.io within NestJS, using:

- **HandshakeMiddleware** — validates JWT on every new connection, rejects unauthenticated sockets immediately
- **WsAuthGuard** — protects individual gateway event handlers
- **RedisIoAdapter** — replaces the default adapter, enabling horizontal scaling across multiple NestJS instances
- **Redis Key/Value** — shared state store accessible by all instances (grace flags, host tracking)
- **Bull Queue** — crash-proof delayed job scheduler backed by Redis

---

## HTTP vs WebSocket — Decision Rule

> Use **HTTP** when the action has no real-time side effect on other users.
> Use **WebSocket** when the action must immediately notify other connected users.

| Action | Layer | Reason |
|---|---|---|
| `POST /events` | HTTP | Creates the event in DB, no one to notify yet |
| `GET /events` | HTTP | Pure data fetch |
| `PATCH /events/:id` | HTTP | Edits metadata, no real-time effect |
| `DELETE /events/:id` | HTTP | No active room to notify |
| `event:start` | WebSocket | Must notify all users waiting in the room instantly |
| `event:end` | WebSocket | Must notify all users currently in the room instantly |
| `event:join` | WebSocket | User enters the event room, others should know |
| `event:leave` | WebSocket | User leaves the event room, others should know |

### Why `event:start` Must Be WebSocket

If `start` were an HTTP endpoint, Instance A would mark the event as live in the DB, but broadcasting to the Socket.io room would only reach clients connected to Instance A. Users on Instance B would be missed. Because the gateway uses the Redis adapter, emitting from a WebSocket handler automatically routes through Redis Pub/Sub and reaches every client regardless of which instance they are on.

---

## Host Identity vs. Socket Identity

This is a critical distinction that affects every part of the disconnection and rejoin logic.

A **user identity** is stable and persistent — it is the `userId` stored in the DB, attached to the socket via JWT on every connection.

A **socket identity** is ephemeral — it is the `socketId` generated fresh every time a socket connects. The same user reconnecting after a network drop will have a completely different `socketId`.

```
User 1 connects at T+0s    →  socketId: "abc123"
User 1 loses wifi at T+30s →  socket "abc123" is dead
User 1 reconnects at T+45s →  socketId: "xyz789"  ← completely new
```

### Why This Matters

The host of an event is identified by their **userId** (`event.creatorId` in the DB), not their socketId. When the host reconnects after a drop, you must validate their identity against `userId`, not look for their old `socketId` — which no longer exists.

Concretely, when storing the host reference in Redis, store the `userId` as the authority, not the `socketId`:

```
event-host:{eventId}  →  userId:1        ← stable, use this for identity checks
host-socket:{eventId} →  socketId:xyz789 ← ephemeral, update on every rejoin
```

This means:
- Ownership checks (`event.creatorId === socket.user.id`) use `userId` — always correct
- The Redis `host-disconnect` grace flag stores `userId` — survives reconnections
- The `host-socket` key is updated every time the host rejoins — used only for targeted emits, never for identity

If you stored `socketId` as the source of truth for host identity, the host would be permanently "unknown" after every reconnection, breaking the entire rejoin flow.

---

## Joining an Event — Gatekeeping Logic

When a user emits `event:join`, the server must decide whether to let them in. The checks that apply here are specific to the **event lifecycle**, not to the voting/playlist features.

### What Is Checked in `event:join`

```
User emits event:join { eventId }
│
├── 1. Does the event exist in DB?          → if not: reject with WsException
├── 2. Is the event ended?                  → if yes: reject, event is over
├── 3. Is the event private?
│       └── if yes: is the user invited?   → if not: reject, access denied
└── 4. All checks pass → user joins the room
```

### What Is NOT Checked in `event:join`

**License rules are not checked here.** Licenses in this project govern voting behavior (who can vote, geo-restricted voting, time-restricted voting) — they belong to the Music Track Vote feature, not to the event room lifecycle.

Joining an event is a presence action — you are entering a space to listen and participate. Whether you can vote once inside is a separate concern enforced at the `track:vote` handler level, not at the door.

Mixing license checks into `event:join` would create the wrong mental model: a user without a voting license should still be able to join the room and see the event — they just cannot cast votes. Blocking them at `event:join` would incorrectly exclude them from the event entirely.

```
event:join checks:    event exists? + event not ended? + visibility allowed?
track:vote checks:   license valid? + geo constraint? + time window valid?
```

---

## Starting an Event

Only the host (event creator) can emit this. The server validates ownership using `userId`, not `socketId`.

- The host could start only one event not multiple events at the same time

### Flow

```
Host emits event:start { eventId }
│
├── Server validates: event.creatorId === socket.user.id  ← userId check
├── DB: event status updated to 'live'
├── Redis: set 'event-host:{eventId}' = userId            ← store userId, not socketId
├── Redis: set 'host-socket:{eventId}' = socketId         ← store socketId separately
└── Broadcast to room: event:started { eventId, startedAt, hostId }
    ├── All waiting users receive it (already in the room)
    └── Redis adapter ensures delivery across all instances
```

### Users Who Join After Start

When a user emits `event:join` for an already-live event, the `event:join` handler checks the DB status and immediately emits `event:status { status: 'live' }` back to the joiner. The client skips the waiting screen and enters the live view directly.

---

## Host Disconnection — Two-Stage Grace Period

### The Problem

A flat 90-second grace period is too blunt. From the moment the host disconnects, two very different situations need different treatment:

- **T+0s to T+5s**: almost certainly a brief network hiccup — no user action needed, just wait silently
- **T+5s to T+90s**: long enough that users should be explicitly warned, but the host may still be navigating back

The solution is a **two-stage approach**: a soft disconnect warning at T+5s and a hard termination at T+90s.

### Why Not `setTimeout`

`setTimeout` lives in the NestJS process memory. If the server crashes or restarts during the grace window, the timeout is lost and the room hangs indefinitely. Bull Queue stores jobs in Redis, so they survive any server crash and are picked up by whichever instance is alive when the delay expires. Both the soft and hard jobs are stored in Bull.

---

### Stage 1 — Soft Disconnect (T+5s)

```
T+0s   Host loses connection
│
├── handleDisconnect fires
├── Redis: set 'host-disconnect:{eventId}' = userId  (TTL: 95s as safety net)
├── Bull: schedule job 'host-soft-timeout'  →  fires in 5s
├── Bull: schedule job 'host-hard-timeout'  →  fires in 90s
└── (no broadcast yet — too early, likely just a flicker)


T+5s   Bull job 'host-soft-timeout' fires
│
├── Check Redis: 'host-disconnect:{eventId}' still present?
│   ├── NO  → host rejoined already, job is stale, do nothing
│   └── YES → host is still gone after 5s
└── Broadcast to room: event:host_soft_disconnect { gracePeriodSeconds: 85 }
    └── UI shows a visible warning: "Host lost connection, waiting up to 85s..."
```

The 5-second delay before warning avoids flooding users with panic messages on every brief wifi hiccup. If the host reconnects in under 5 seconds, users see nothing at all — the event never appeared interrupted.

---

### Stage 2 — Hard Disconnect (T+90s)

```
T+90s  Bull job 'host-hard-timeout' fires
│
├── Check Redis: 'host-disconnect:{eventId}' still present?
│   ├── NO  → host rejoined, job is stale, do nothing
│   └── YES → host never came back
├── DB: event status updated to 'ended'
├── Broadcast to room: event:ended { reason: 'host_unreachable' }
│   └── All users are redirected away
└── Redis cleanup:
    ├── delete 'host-disconnect:{eventId}'
    ├── delete 'event-host:{eventId}'
    └── delete 'host-socket:{eventId}'
```

---

### Reconnection Flow (Host Returns in Time)

The host's socket auto-reconnects silently in the background. This does **not** automatically rejoin them to the event room — the host must navigate to their hosted events screen and explicitly click Rejoin.

```
T+Ns   Host socket auto-reconnects (background, silent)
       handleConnection fires → JWT validated → nothing event-related happens
       userId is known, socketId is brand new

T+Ns   Host opens events screen → sees event marked LIVE
       Host clicks Rejoin → emits event:host_rejoined { eventId }
│
├── Server detects: event.creatorId === socket.user.id  ← userId match
├── Server checks Redis: 'host-disconnect:{eventId}' → found
├── Bull: cancel 'host-soft-timeout' job (if not yet fired)
├── Bull: cancel 'host-hard-timeout' job
├── Redis: delete 'host-disconnect:{eventId}'
├── Redis: update 'host-socket:{eventId}' = new socketId
├── Host rejoins socket room event:{eventId}
└── Broadcast to room: event:host_reconnected { hostId }
    └── All users see: "Host is back, resuming..."
```

If the host returns between T+5s and T+90s, users who saw the soft disconnect warning will now see the reconnected message — closing the feedback loop cleanly.

---

### Timeout Diagram

```
T+0s    Host disconnects
         │
         ├── Redis flag set (userId)
         ├── Bull soft job scheduled → fires at T+5s
         └── Bull hard job scheduled → fires at T+90s

T+5s    Soft job fires
         ├── flag still present? → warn the room (countdown UI)
         └── flag gone?          → host already back, do nothing

             ┌──────────────────────────────────────────┐
             │  Host can rejoin anywhere in this window  │
             │  Both jobs canceled, room notified        │
             └──────────────────────────────────────────┘

T+90s   Hard job fires
         ├── flag still present? → end the event, notify room, cleanup Redis
         └── flag gone?          → host already back, do nothing
```

---

## Host Ends the Event Explicitly

The host can end the event intentionally at any time using a dedicated WebSocket event. This is completely separate from the disconnection flow — no grace period, no Bull jobs, immediate termination.

### Flow

```
Host emits event:end { eventId }
│
├── Server validates: event.creatorId === socket.user.id  ← userId check
├── DB: event status updated to 'ended'
├── Redis cleanup:
│   ├── delete 'event-host:{eventId}'
│   └── delete 'host-socket:{eventId}'
└── Broadcast to room: event:ended { reason: 'host_ended' }
    └── All users are redirected away immediately
```

---

## Redis — Role Summary

Redis serves two completely separate purposes in this system:

### 1. Socket.io Adapter (Pub/Sub)

Synchronizes room broadcasts across all NestJS instances. When any instance calls `this.server.to('event:456').emit(...)`, the Redis adapter publishes to a Redis channel, which forwards the message to all other instances, which deliver it to their locally connected clients.

Without this, a broadcast on Instance A would never reach clients on Instance B.

### 2. Shared State (Key/Value)

Stores flags and references that any instance needs to read or write, regardless of which instance the relevant socket is connected to.

| Key | Value | Purpose |
|---|---|---|
| `event-host:{eventId}` | userId | Stable host identity — never changes mid-event |
| `host-socket:{eventId}` | socketId | Current host socket — updated on every rejoin |
| `host-disconnect:{eventId}` | userId | Grace period flag — present means host is away |
| Bull job `host-soft-timeout` | job payload | Soft warning scheduled for T+5s |
| Bull job `host-hard-timeout` | job payload | Hard termination scheduled for T+90s |

---

## Redis State Lifecycle

```
Event is live, host connected:
  event-host:456        → "userId:1"
  host-socket:456       → "socketId:abc"
  host-disconnect:456   → (not set)

Host disconnects, grace period active:
  event-host:456        → "userId:1"              (unchanged — userId never changes)
  host-socket:456       → "socketId:abc"          (stale, not yet cleaned)
  host-disconnect:456   → "userId:1"              (TTL: 95s)
  bull soft job         → pending, fires at T+5s
  bull hard job         → pending, fires at T+90s

Host rejoins in time:
  event-host:456        → "userId:1"              (unchanged)
  host-socket:456       → "socketId:xyz"          (updated to new socket)
  host-disconnect:456   → DELETED
  bull soft job         → DELETED (canceled)
  bull hard job         → DELETED (canceled)

Host never returns, event ended:
  event-host:456        → DELETED
  host-socket:456       → DELETED
  host-disconnect:456   → DELETED
  bull soft job         → DELETED (executed)
  bull hard job         → DELETED (executed)
```

---

## WebSocket Events Reference

| Event | Direction | Description |
|---|---|---|
| `event:join` | Client → Server | Join an event room (pending or live) |
| `event:leave` | Client → Server | Leave an event room |
| `event:start` | Client → Server | Host starts the event |
| `event:end` | Client → Server | Host ends the event explicitly |
| `event:status` | Server → Client | Sent to joiner with current event state |
| `event:started` | Server → Room | Broadcast when host starts |
| `event:ended` | Server → Room | Broadcast when event ends (any reason) |
| `event:host_soft_disconnect` | Server → Room | Host gone 5s+, grace period countdown starts |
| `event:host_reconnected` | Server → Room | Host rejoined successfully |
| `event:user_joined` | Server → Room | Another user joined the room |

---

## Complete Timeline — All Scenarios

```
[Phase 1] Host creates event
  POST /events → DB: status = 'pending'

[Phase 2] Users join waiting room
  event:join
  → checks: event exists? + not ended? + visibility allowed?  (no license check)
  → joined socket room → event:status { pending } → waiting screen

[Phase 3] Host starts event
  event:start
  → validated by userId (not socketId)
  → DB: status = 'LIVE'
  → Redis: event-host = userId, host-socket = socketId
  → broadcast event:started → all waiting users enter live view

[Phase 4a] Host disconnects accidentally
  handleDisconnect
  → Redis flag set (userId)
  → Bull soft job (T+5s) + hard job (T+90s) scheduled

  [4a-i] Host back before T+5s
    socket reconnects (silent) → host navigates → event:join (userId validated)
    → both Bull jobs canceled → Redis flag deleted
    → room never warned → seamless recovery

  [4a-ii] Host back between T+5s and T+90s
    T+5s  → soft job fires → room warned (countdown UI shows remaining time)
    T+Ns  → host navigates → event:host_rejoined (userId validated)
           → hard Bull job canceled → Redis flag deleted
           → broadcast event:host_reconnected → countdown dismissed

  [4a-iii] Host never returns
    T+5s  → soft job fires → room warned
    T+90s → hard job fires → DB: ended → broadcast event:ended → users redirected

[Phase 4b] Host ends event intentionally
  event:end
  → validated by userId
  → DB: ended → Redis cleanup → broadcast event:ended → users redirected immediately
```
