# Phase 2: Collaborative Drag-and-Drop Reordering

This plan implements real-time drag-and-drop playlist synchronization. It uses a "negative-position" swap algorithm within PostgreSQL to cleanly bypass `UNIQUE` constraints and instantly lock the database rows during high-concurrency reordering.

## Proposed Changes

### 1. `src/playlists/dto/reorder-track.dto.ts`
- **[NEW]**: Create the `ReorderTrackDto` class.
- Will strictly validate the payload with `class-validator`:
  ```typescript
  @IsNumber()
  @Min(1)
  newPosition!: number;
  ```

### 2. `src/playlists/playlists.controller.ts`
- **[MODIFY]**: Add the endpoint:
  `PATCH /playlists/:id/tracks/:trackId/reorder`
- Route parameters: UUID `id` (playlist ID), UUID `trackId` (PlaylistTrack ID).
- Response: `200 OK` on successful reorder. Swagger annotations will document all possible HTTP error guards (403, 404, 400).

### 3. `src/playlists/playlists.service.ts`
- **[MODIFY]**: Add `reorderTrack(playlistId, trackId, requesterId, newPosition)`
  - Run the `verifyEditAccess()` firewall as usual to immediately reject unauthorized actors from moving tracks in RESTRICTED or PRIVATE playlists.
  - Evaluate and normalize out-of-bounds position requests (e.g., if a user drags to position 100 on a 5-track playlist, we gracefully snap it directly to position 5).
  - Execute `playlistsRepository.reorderTrack`.
  - Broadcast the real-time event to `playlist_<id>` via `PlaylistsGateway.server.to().emit(...)`.

### 4. `src/playlists/playlists.repository.ts`
- **[MODIFY]**: Implement `reorderTrack(playlistId, trackId, newPosition)`
  - Run inside a unified `this.prisma.$transaction`.
  - **The Algorithm**:
    1. Retrieve the existing track to capture `oldPosition`.
    2. Immediately park the dragged track at an illegal position (`-1`) to free up its DB slot.
    3. Shift the surrounding range via `updateMany` using Postgres native mathematical modifiers (`increment: 1` or `decrement: 1`) based on whether the track moved forwards or backwards.
    4. Slot the parked track exactly into `newPosition`.
    5. Run a `findMany` to select the `id` and `position` of all tracks specifically within the range of `[Math.min(oldPos, newPosition), Math.max(oldPos, newPosition)]`. This precisely captures every affected track.

### 5. `docs/websocket_contract.md`
- **[MODIFY]**: Define the new WebSocket contract for clients to listen to:
  - **Event**: `playlist:track:reordered`
  - **Payload**:
    ```json
    {
      "playlistId": "123",
      "updates": [
        { "trackId": "uuid-for-B", "position": 4 },
        { "trackId": "uuid-for-C", "position": 2 },
        { "trackId": "uuid-for-D", "position": 3 }
      ]
    }
    ```

## User Review Required

> [!IMPORTANT]
> This new idempotent batch-update approach is vastly superior to the delta approach. I've updated the plan so that the backend queries the explicit state of the affected range immediately before returning the payload, ensuring the frontend is always fed absolute, self-healing truth directly from PostgreSQL. Does this plan version look good?

## Verification Plan

### Automated Tests
- Scaffold `PlaylistsService.reorderTrack` tests using our updated dependency mocking architecture.
- Fire integration tests mapping the E2E lifecycle (create, drag, remove).

### Integration Safety
- Relying on Prisma's `.test()` logic, ensuring that moving positions up or down does not crash via the `@@unique([playlistId, position])` PostgreSQL constraint.
