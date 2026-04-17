# **Product Specification: Music Room**

Music Room supports real-time voting in Live Events, delegated music control, and a real-time collaborative playlist editor with visibility and license rules.

## **Clarifications (Architectural Decisions)**

* **Q: Does the Playlist Editor play music?** \-\> A: **No.** The Playlist Editor is purely a preparation phase (like a collaborative Google Doc) focused on drag-and-drop indexing. Audio playback and queue consumption *only* happen within a Live Event.
* **Q: How does an Event queue initialize?** \-\> A: An Event starts empty by default, but the Host has the option to "Import" an existing saved Playlist, which copies the tracks into the live event queue.
* **Q: What is the concurrency tie-breaker for Live Event votes?** \-\> A: Last-write-wins by server timestamp; exact tie goes to the lower track entry identifier.
* **Q: What is the concurrency tie-breaker for Playlist drag-and-drop?** \-\> A: Strict PostgreSQL row-level locking. If two users drag simultaneously, the second transaction waits for the first to complete and calculates the new shifted indexes.
* **Q: How is the physical location and time license validated?** \-\> A: Backend validates GPS coordinates and active time windows using the authoritative server clock.
* **Q: Does public content discovery require authentication?** \-\> A: Yes, a user must be logged in to search for public events or playlists.

## **User Scenarios & Testing (Mandatory)**

### **User Story 1 \- Vote-Driven Live Party Event (Priority: P1)**

**As an event participant, I can suggest tracks and vote on upcoming tracks so the party queue reflects the group's real-time preference.**

* *Why this priority:* This is the core consumption use case. Music plays from the Host's phone while guests silently control the upcoming queue via democracy.
* *Acceptance Scenarios:*
  * **Given** a Host creates a new Event, **When** they select an existing Playlist, **Then** the event initializes by copying the playlist's tracks into the active Event Queue (all starting with 0 votes).
  * **Given** a live Event, **When** a track finishes playing on the Host's device, **Then** the server marks the track as PLAYED and automatically broadcasts the next highest-voted track to play.
  * **Given** multiple tracks in the queue, **When** users upvote/downvote, **Then** the queue instantly re-sorts deterministically based on total voteScore.
  * **Given** a participant already upvoted a track, **When** they tap upvote again, **Then** the vote is toggled off and the ranking adjusts.
  * **Given** an Event is licensed by location/time, **When** an out-of-bounds user tries to join or vote, **Then** access is denied with an eligibility error.
  * **Given** a Private Event, **When** a non-invited user searches for it, **Then** the event is hidden and inaccessible.

### **User Story 2 \- Delegated Playback Control / "Pass the Aux" (Priority: P2)**

**As an Event Host, I can delegate physical playback controls (skip/pause) to selected friends tied to their specific hardware devices.**

* *Why this priority:* Fulfills the strict "licensed device specifically" grading criteria and prevents the Host from being a bottleneck during a party.
* *Acceptance Scenarios:*
  * **Given** a live Event, **When** the Host delegates control to a friend, **Then** the backend records the friend's unique deviceId.
  * **Given** a delegated friend logs into their account on a *different* iPad, **When** they try to skip a track, **Then** the backend rejects the action because the hardware deviceId does not match.
  * **Given** the Host revokes delegation, **When** the friend attempts to pause the music, **Then** the action is immediately blocked.

### **User Story 3 \- Real-Time Collaborative Playlist Editor (Priority: P3)**

**As a user, I can co-edit saved playlists in real-time with invited friends to prepare music for future events.**

* *Why this priority:* Fulfills the "licensed to specific users" criteria and allows asynchronous preparation without the chaos of a live party.
* *Acceptance Scenarios:*
  * **Given** a Playlist Editor session, **When** a user searches for a track via the YouTube API and adds it, **Then** it drops into the list and is broadcast to all collaborators.
  * **Given** an active Editor session, **When** a user drags Track \#10 to position \#2, **Then** the server locks the rows, updates the indexes safely, and broadcasts the new exact order to all screens.
  * **Given** edit access is restricted to "invited users", **When** a non-collaborator tries to add a track, **Then** the backend returns a 403 Forbidden.

## **Edge Cases to Handle**

1. A user attempts to drag-and-drop a track in a Live Event (Blocked: Live Events only sort by Votes, not manual positions).
2. A user attempts to vote on a track in the Playlist Editor (Blocked: Playlists only sort by manual positions, not Votes).
3. The Host's phone disconnects from WebSockets while playing a song. (The backend currentTrackStartedAt preserves the exact timeline so the Host can reconnect and sync instantly).
4. Two users drag and drop overlapping track ranges in the Playlist Editor simultaneously.
5. A Private Event Host changes the room visibility to Public while users are inside.
6. The YouTube API rate-limits the backend during a heavy track-search spike.

## **Requirements (Mandatory)**

### **Functional Requirements (FR)**

**Live Events & Playback**

* **FR-E01:** System MUST allow a Host to create a Live Event and act as the sole audio playback source.
* **FR-E02:** System MUST synchronize guest UI progress bars using a backend-provided currentTrackStartedAt timestamp (Guests do not stream audio).
* **FR-E03:** System MUST allow Host to import tracks from a saved Playlist into a Live Event Queue.
* **FR-E04:** System MUST strictly order the Live Event Queue dynamically based on voteScore.
* **FR-E05:** System MUST soft-delete tracks (change status to PLAYED) when playback finishes to advance the queue.
* **FR-E06:** System MUST evaluate physical license constraints (Geofence, Time Window) before allowing a guest to join or vote in an Event.
* **FR-E07:** System MUST enforce a digital "Invite" license for Private Events.

**Delegation**

* **FR-D01:** System MUST allow the Host to grant Playback Control (Skip/Pause) to a specific user.
* **FR-D02:** System MUST strictly bind this delegation to the user's specific hardware deviceId.

**Playlist Editor**

* **FR-P01:** System MUST provide a collaborative editor for creating persistent Playlists without active audio playback.
* **FR-P02:** System MUST strictly order Playlists using a manual integer position (Drag-and-drop).
* **FR-P03:** System MUST use database transaction locks to prevent index corruption during concurrent drag-and-drop actions.
* **FR-P04:** System MUST restrict private playlist editing strictly to users with a PlaylistCollaborator record.

### **API & Operational Requirements (OSR)**

* **OSR-001:** System MUST use a centralized Track dictionary to prevent duplicating YouTube metadata across Playlists and Events.
* **OSR-002:** System MUST use WebSockets (e.g., Socket.io) to broadcast state changes (Votes, Index shifts, Playback state) in real-time.
* **OSR-003:** System MUST store all user profiles and license configurations using native JSON data types.
* **OSR-004:** System MUST record an AuditLog of all critical user actions (Login, Vote, Move Track, Skip Track).

## **Key Entities (Prisma Schema Map)**

* **User:** The core account. Contains publicInfo, friendInfo, privateInfo, and preferences stored strictly as JSON.
* **Track:** The normalized Audio Dictionary. Stores the providerTrackId (YouTube API ID), title, duration, and thumbnail exactly once.
* **Event:** The Live Party. Contains playback state (currentTrackId, currentTrackStartedAt). Ordered democratically.
* **EventTrack:** A track actively sitting in an Event queue. Sorted strictly by voteScore.
* **Playlist:** The preparation workspace. A persistent container for tracks.
* **PlaylistTrack:** A track saved in a playlist. Sorted strictly by manual position integer.
* **Vote:** A unique \+1 or \-1 linked to a User and an EventTrack.
* **ControlDelegation:** The "Pass the Aux" license. Binds an Event, a Delegatee (User), and a specific hardware deviceId.
* **LicensePolicy:** The physical event constraints. Stores geofencing arrays or time-windows as JSON.
* **PlaylistCollaborator:** The digital editor constraint. Explicitly lists who is licensed to edit a specific private playlist.
* **EventInvite:** The digital party constraint. Explicitly lists who is allowed to discover and join a private live event.
* **AuditLog:** An isolated ledger recording user actions, device models, and timestamps for grading compliance.

## **Success Criteria**

* **SC-001 (Concurrency):** 10 simultaneous users dragging tracks in the Playlist Editor results in 0 duplicated position indexes in the database.
* **SC-002 (Real-Time):** A track upvote during a Live Event updates the UI order on all connected clients within 500ms.
* **SC-003 (License):** A user logging into a secondary device is successfully blocked from executing a delegated "Skip" command.
* **SC-004 (Audio):** The app successfully plays full tracks via the YouTube API without requiring Spotify Premium authentication from the evaluators.
