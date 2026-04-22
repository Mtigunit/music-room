## Plan: Add Append Track Endpoint & Refactor Track Payload & add remove track endpoint 

This plan updates the payload requirements to strictly use `providerTrackId` for linking tracks. A placeholder function will be implemented to fetch the missing metadata until the actual external provider integration is ready.

**Steps**
1. **Refactor DTO**: Update [backend/src/events/dto/append-tracks.dto.ts](backend/src/events/dto/append-tracks.dto.ts) to only contain the `providerTrackId` property (removing `title`, `artist`, `durationMs`, and `thumbnailUrl`). This implicitly updates `CreateEventDto` to expect only the external ID as well.
2. **Metadata Placeholder**: Add a private placeholder method `getTracksDetails(providerTrackIds: string[])` in [backend/src/events/events.repository.ts](backend/src/events/events.repository.ts) (or `EventsService`) that mocks and returns the track metadata array as you specified (`{ providerTrackId, title, artist, durationMs, thumbnailUrl }`).
3. **Extend Repository for Appending**: Add `appendTrack(id, userId, dto: AppendedTrackDto)` in [backend/src/events/events.repository.ts](backend/src/events/events.repository.ts).
   - Verify event permissions (must be public, host, or invited).
   - Check if the track exists in the DB. If not, call the `getTracksDetails` placeholder and `prisma.track.create` it.
   - Attach the track to the event via `prisma.eventTrack.create` (throwing a `ConflictException` if it's already queued).
- **Extend Repository for Removing**: Add `removeTrack(eventId: string, trackId: string, userId: string)` in [backend/src/events/events.repository.ts](backend/src/events/events.repository.ts).
   - Verify event permissions (must be public, host, or invited).
   - Check if the `EventTrack` exists for the given `eventId` and `trackId`. Throw `NotFoundException` if it doesn't.
   - Detach the track from the event via `prisma.eventTrack.delete`.

4. **Update `create` Event Flow**: Modify the existing `create` method in `EventsRepository` to use the `getTracksDetails` placeholder for the `tracks` array before running the Prisma transaction to create the event and its tracks. 
5. **WebSocket & Controller Export**: 
   - Export `SocketIoGateway` from [backend/src/websockets/websockets.module.ts](backend/src/websockets/websockets.module.ts) and import `WebsocketsModule` into `EventsModule`.
   - Inject the Gateway into [backend/src/events/events.service.ts](backend/src/events/events.service.ts).
   - In `EventsService.appendTrack`, await the repository result and emit: `this.socketIoGateway.server.to(id).emit('track:added', newTrack);`.
   - In `EventsService.removeTrack`, await the repository result and emit: `this.socketIoGateway.server.to(eventId).emit('track:removed', { trackId });`.
6. **Controller Endpoints**:
   - Add `POST /events/:eventId/tracks` in [backend/src/events/events.controller.ts](backend/src/events/events.controller.ts) using `@UseGuards(JwtAuthGuard)` and `AppendedTrackDto`.
   - Add `DELETE /events/:eventId/tracks/:trackId` using `@UseGuards(JwtAuthGuard)` to allow a user to remove a track from an event.

**Verification**
- Test creating an event with an array of just `{ providerTrackId: "..." }`. Verify the mock metadata is saved to the DB.
- Test `POST /events/:eventId/tracks` with a single ID. Verify returning `201` and the WS emission `track:added` to the specific `eventId` room.
- Test `DELETE /events/:eventId/tracks/:trackId`. Verify returning `200` (or `204`), DB deletion, and the WS emission `track:removed` to the `eventId` room. Also test with a user lacking permissions to ensure `403 Forbidden` is returned.

**Decisions**
- `AppendedTrackDto` was kept as an object (`{ providerTrackId: string }`) instead of raw strings to allow for easy extensibility in the future (e.g., adding user-specific tags or track sources) without breaking clients.
- The `getTracksDetails` placeholder returns an array to easily accommodate both single append and multiple track initialization during event creation.



