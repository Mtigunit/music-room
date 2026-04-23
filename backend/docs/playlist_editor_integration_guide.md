# Flutter Playlist Editor — Implementation Plan

This document is the complete backend-to-frontend contract and implementation guide for the Flutter team building the real-time collaborative playlist editor.

## Background & Architecture Summary

The backend exposes a **REST API** for mutations (add, remove, reorder tracks) and a **Socket.io WebSocket** for real-time broadcasts. The client must:

1. Fetch the playlist via REST on screen open.
2. Connect to a WebSocket room to receive live updates from other collaborators.
3. Send mutations via REST, receive the server's authoritative response, and update local state.
4. Handle incoming WebSocket events from *other* users to keep the list in sync.

> [!IMPORTANT]
> **Optimistic Concurrency Control (OCC):** The `reorder` endpoint requires a `baseUpdatedAt` timestamp. The client must always track the latest `updatedAt` value and send it with every reorder request. A `409 Conflict` means your local state is stale — you must re-fetch.

---

## 1. Domain Layer (`features/playlist/domain/`)

### 1.1 Entities

#### `Track`
| Field | Type | Description |
|---|---|---|
| `id` | `String` | Unique ID (UUID) of the Track in the dictionary |
| `providerTrackId` | `String` | YouTube video ID |
| `title` | `String` | Track title |
| `artist` | `String` | Channel / artist name |
| `durationMs` | `int` | Duration in milliseconds |
| `thumbnailUrl` | `String?` | Thumbnail URL |

#### `PlaylistTrack`
| Field | Type | Description |
|---|---|---|
| `id` | `String` | UUID of the PlaylistTrack join record |
| `position` | `int` | 0-based index in the playlist |
| `addedById` | `String` | UUID of the user who added it |
| `track` | `Track` | Nested track metadata |

#### `Playlist`
| Field | Type | Description |
|---|---|---|
| `id` | `String` | UUID |
| `name` | `String` | Playlist name |
| `visibility` | `String` | `PUBLIC` or `PRIVATE` |
| `editLicense` | `String` | `OPEN` or `RESTRICTED` |
| `updatedAt` | `String` | ISO-8601 timestamp (**critical for OCC**) |
| `tracks` | `List<PlaylistTrack>` | Ordered list of tracks |

---

## 2. Data Layer (`features/playlist/data/`)

### 2.1 REST API Contract

All endpoints require `Authorization: Bearer <jwt>`.

#### `GET /playlists/:id` — Fetch playlist details
- **Response:** Full playlist object including `tracks[]` sorted by `position`, and `updatedAt`.
- **Usage:** Called once when the editor screen opens.

#### `POST /playlists/:id/tracks` — Add a track
- **Request Body:** `{ "providerTrackId": "dQw4w9WgXcQ" }`
- **201 Response:** `{ "newUpdatedAt": "...", "track": { PlaylistTrack object } }`
- **Error Codes:**
  - `400` — Playlist at max capacity (300 tracks) or invalid input
  - `403` — Not authorized to edit
  - `404` — Playlist or YouTube track not found
  - `409` — Duplicate track already in playlist

#### `DELETE /playlists/:id/tracks/:playlistTrackId` — Remove a track
- **200 Response:** `{ "newUpdatedAt": "...", "deletedTrack": { ... }, "updates": [...] }`
- **Error Codes:**
  - `403` — Not authorized (not owner/collaborator, or didn't add the track)
  - `404` — Playlist or track not found

#### `PATCH /playlists/:id/tracks/:playlistTrackId/reorder` — Reorder a track
- **Request Body:**
  ```json
  {
    "newPosition": 0,
    "baseUpdatedAt": "2026-04-23T10:00:00.000Z"
  }
  ```
- **200 Response:** `{ "newUpdatedAt": "..." }`
- **Error Codes:**
  - `400` — Invalid position (float, negative)
  - `403` — Not authorized
  - `404` — Playlist or track not found
  - `409` — **OCC Failure** — playlist was modified by another user

> [!IMPORTANT]
> **API Client Requirement:** The shared `ApiClient` in `core/network/` must be updated to include a `PATCH` method to support this endpoint.

> [!CAUTION]
> `newPosition` must be an **integer** (`int`). The backend rejects floats with `400 Bad Request`.
> `baseUpdatedAt` must be the **exact ISO-8601 string** returned by the last successful mutation. Do not truncate or re-format it.

### 2.2 WebSocket Contract

- **Path:** `/ws`
- **Transport:** `websocket`
- **Library:** Use the `socket_io_client` Dart package.
- **Auth:** `{ auth: { token: "<jwt>" } }`

#### Client → Server Events

| Event | Payload | Description |
|---|---|---|
| `playlist:join` | `{ "playlistId": "<uuid>" }` | Join the playlist room on screen open |
| `playlist:leave` | `{ "playlistId": "<uuid>" }` | Leave the room on screen dispose |

#### Server → Client Broadcast Events

| Event | Payload | When |
|---|---|---|
| `playlist:track:added` | Full `PlaylistTrack` object (with nested `track`) | Another user added a track |
| `playlist:track:removed` | `{ "playlistId", "deletedTrackId", "updates": [{ "trackId", "position" }] }` | Another user removed a track |
| `playlist:track:reordered` | `{ "playlistId", "updates": [{ "trackId", "position" }] }` | Another user reordered a track |

> [!NOTE]
> The `updates` array in `removed` and `reordered` events contains the **new absolute positions** for every track that shifted. Apply these by matching `trackId` to your local list and updating their `position` field, then re-sort.

---

## 3. State Management — BLoC (`presentation/state/`)

### 3.1 Events (Input)

```
PlaylistEditorOpened(playlistId)         → fetch playlist + join WS room
PlaylistEditorClosed()                   → leave WS room + dispose
TrackSearched(query)                     → search YouTube API
TrackAdded(providerTrackId)              → POST /tracks
TrackRemoved(playlistTrackId)            → DELETE /tracks/:id
TrackReordered(playlistTrackId, newPos)  → PATCH /tracks/:id/reorder

// WebSocket-driven (internal events from WS listener):
_WsTrackAdded(playlistTrack)
_WsTrackRemoved(deletedTrackId, updates)
_WsTrackReordered(updates)
```

### 3.2 State

```dart
class PlaylistEditorState {
  final bool isLoading;
  final String? errorMessage;
  final Playlist? playlist;          // Contains tracks + updatedAt
  final String? latestUpdatedAt;     // OCC Timestamp (CRITICAL)
  final bool isReordering;           // Lock drag-and-drop during pending request
  final bool showStaleWarning;       // Show "Refresh" banner on 409
}
```

### 3.3 Critical OCC Flow (Reorder)

```
User drags track → emit TrackReordered(trackId, newPos)
  │
  ├─ Set isReordering = true (disable further drags)
  ├─ Optimistic UI: move track locally in the list
  ├─ Send PATCH with { newPosition, baseUpdatedAt: latestUpdatedAt }
  │
  ├─ 200 OK:
  │    ├─ Update latestUpdatedAt = response.newUpdatedAt
  │    └─ Set isReordering = false
  │
  ├─ 409 Conflict (OCC Failure):
  │    ├─ REVERT the optimistic UI change
  │    ├─ Show snackbar: "Someone else edited. Refreshing..."
  │    ├─ Re-fetch GET /playlists/:id to get authoritative state
  │    └─ Update latestUpdatedAt from the fresh fetch
  │
  └─ Other error:
       ├─ REVERT the optimistic UI change
       └─ Show error snackbar
```

> [!WARNING]
> You **must** disable drag-and-drop while a reorder request is in-flight (`isReordering = true`). If the user drags again before the first request completes, the second drag will use a stale `baseUpdatedAt` and will always fail with `409`.

### 3.4 WebSocket Event Handling

When the BLoC receives a broadcast event from another user:

1. **`playlist:track:added`** → Append the new `PlaylistTrack` to the local list. Update `latestUpdatedAt` if provided.
2. **`playlist:track:removed`** → Remove the track by `deletedTrackId`. Apply all `updates[]` position shifts to the remaining tracks. Re-sort.
3. **`playlist:track:reordered`** → For each entry in `updates[]`, find the matching track by `trackId` and set its new `position`. Re-sort.

> [!IMPORTANT]
> Do **NOT** apply WS events for actions you initiated yourself. The REST response already updated your local state. Applying the WS echo would cause a double-update. Filter by checking if the event's `trackId` matches a pending local mutation.

---

## 4. Presentation Layer (`presentation/`)

### 4.1 Page: `PlaylistEditorPage`

Top-level screen. Responsibilities:
- Provide the BLoC.
- Call `PlaylistEditorOpened` on init, `PlaylistEditorClosed` on dispose.
- Show loading shimmer while fetching.
- Show a "Stale Data" banner (dismissible) when OCC conflict occurs.

### 4.2 Widget: `TrackListView`

The core scrollable list. Responsibilities:
- Render `PlaylistTrack` items sorted by `position`.
- Implement **drag-and-drop** reordering via Flutter's `ReorderableListView`.
- Disable drag handles when `isReordering` is true (gray out handles, ignore gestures).
- On `onReorder` callback: emit `TrackReordered` event to BLoC.

### 4.3 Widget: `TrackTile`

A single track row. Shows:
- Thumbnail (from `track.thumbnailUrl`).
- Title and artist.
- Duration formatted as `mm:ss`.
- Drag handle icon (right side).
- Swipe-to-delete or trailing delete button → emits `TrackRemoved`.

### 4.4 Widget: `TrackSearchSheet`

Bottom sheet for searching and adding tracks. Shows:
- Search text field → calls YouTube search API (`GET /tracks/search?q=...`).
- Results list with "Add" button per track.
- "Add" button → emits `TrackAdded(providerTrackId)`.
- Handle `409 Conflict` (duplicate) by showing "Already in playlist" inline.

---

## 5. Error Handling Matrix

| HTTP Status | User-Facing Behavior |
|---|---|
| `400` | Snackbar: "Invalid request" (should not happen with proper UI constraints) |
| `401` | Redirect to login screen |
| `403` | Snackbar: "You don't have permission to edit this playlist" |
| `404` | Snackbar: "Track or playlist not found" + navigate back if playlist deleted |
| `409` (on add) | Snackbar: "This track is already in the playlist" |
| `409` (on reorder) | Revert optimistic change + auto-refresh playlist + snackbar: "Playlist updated by someone else" |
| `500` | Snackbar: "Something went wrong. Please try again." |

---

## 6. File Structure

```
features/playlist/
├── data/
│   ├── datasources/
│   │   └── playlist_remote_datasource.dart    // REST + WS calls
│   ├── models/
│   │   ├── track_model.dart                   // JSON ↔ Track
│   │   ├── playlist_track_model.dart          // JSON ↔ PlaylistTrack
│   │   └── playlist_model.dart                // JSON ↔ Playlist
│   └── repositories/
│       └── playlist_repository_impl.dart
├── domain/
│   ├── entities/
│   │   ├── track.dart
│   │   ├── playlist_track.dart
│   │   └── playlist.dart
│   ├── repositories/
│   │   └── playlist_repository.dart           // Abstract contract
│   └── usecases/
│       ├── get_playlist_usecase.dart
│       ├── add_track_usecase.dart
│       ├── remove_track_usecase.dart
│       └── reorder_track_usecase.dart
└── presentation/
    ├── pages/
    │   └── playlist_editor_page.dart
    ├── state/
    │   ├── playlist_editor_bloc.dart
    │   ├── playlist_editor_event.dart
    │   └── playlist_editor_state.dart
    └── widgets/
        ├── track_list_view.dart
        ├── track_tile.dart
        └── track_search_sheet.dart
```

---

## 7. Implementation Order

1. **Models & Entities** — `Track`, `PlaylistTrack`, `Playlist` with `fromJson`/`toJson`.
2. **Datasource** — REST calls (add, remove, reorder) + WS subscription setup.
3. **Repository** — Concrete impl bridging datasource to domain.
4. **Use Cases** — Thin wrappers for each operation.
5. **BLoC** — Full state machine with OCC tracking and WS listener.
6. **UI** — `PlaylistEditorPage` → `TrackListView` → `TrackTile` → `TrackSearchSheet`.
7. **Integration Test** — Verify drag-and-drop triggers correct REST call with correct `baseUpdatedAt`.
