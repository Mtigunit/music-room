# Technical Architecture: Real-Time Collaborative Playlist Editor

This document outlines the core design decisions, concurrency strategies, and database-level optimizations that enable the Music Room's real-time collaborative editing.

## 1. Concurrency Model: Optimistic Concurrency Control (OCC)

**Decision:** The system utilizes **Optimistic Concurrency Control (OCC)** rather than Pessimistic Locking (row-level locking for the duration of a user session).

### Rationale
In a collaborative environment, users expect a fluid experience where they can interact with data without being blocked by others. Pessimistic locking (e.g., "locking" a playlist while a user is editing) creates a poor UX and increases the risk of abandoned locks during network disconnects.

### Implementation
- Every mutation request must include a `baseUpdatedAt` timestamp.
- The server validates this timestamp against the current database state before allowing the mutation.
- A mismatch triggers a `409 Conflict`, signalling to the client that their local state is stale.

---

## 2. The Atomic "Test-and-Set" Firewall

**Decision:** The OCC validation is performed atomically at the database hardware layer using a `WHERE` clause in an `updateMany` operation.

### The Problem
During high-concurrency (Chaos) testing, it was discovered that evaluating the `updatedAt` timestamp in Node.js memory created a race condition. Multiple concurrent requests would read the same timestamp, pass the check, and attempt to write simultaneously, leading to database deadlocks.

### The Solution
By moving the check into an atomic SQL operation:
```sql
UPDATE "Playlist" SET "updatedAt" = NOW() 
WHERE "id" = :id AND "updatedAt" = :baseUpdatedAt;
```
We utilize PostgreSQL's native row-level serialization. Only the first request succeeds (updating the row); subsequent requests return a "0 rows affected" count and are instantly rejected with a `409 Conflict`. This prevents overlapping transactions from ever entering the `PlaylistTrack` modification logic, effectively eliminating deadlocks.

---

## 3. Database Integrity: DEFERRABLE Unique Constraints

**Decision:** The unique index on `(playlistId, position)` is defined as `DEFERRABLE INITIALLY DEFERRED`.

### Rationale
Standard unique constraints are checked after **every single row update**. When reordering tracks (e.g., moving track 10 to position 1), we must shift multiple tracks. During this shift, two tracks will temporarily occupy the same position number.
- **Standard Index:** Would immediately throw a P2002 error and crash the transaction.
- **DEFERRABLE Index:** Suspends validation until the **end of the transaction Commit**. This allows complex mathematical shifts to complete successfully as long as the final state is unique.

---

## 4. Positional Management: Integer Shifting

**Decision:** The system uses absolute integer positions (`0, 1, 2, ...`) rather than Lexical/Fractional sorting (e.g., `1.5, 1.25`).

### Rationale
- **Predictability:** Integer positions are deterministic and easy to debug.
- **Performance:** PostgreSQL can update thousands of integer rows in a single atomic `updateMany` query utilizing indexed lookups.
- **Scaling:** Lexical sorting eventually hits floating-point precision limits and requires complex "re-balancing" logic. Integer shifting is "self-healing" with every transaction.

---

## 5. Domain-Driven Error Handling

**Decision:** The repository layer throws specific Domain Exceptions (`OccStaleException`) rather than raw string errors or generic Prisma errors.

### Rationale
- **Type Safety:** The service layer can use `instanceof` checks, which are verified by the TypeScript compiler.
- **Safety:** This prevents "Fragile Code" where changing a string message in the database layer could silently break error-handling logic in the API layer.
- **Privacy:** It ensures that raw database implementation details never leak into the HTTP response.

---

## 6. Real-Time Sync: REST + WebSocket Echoes

**Decision:** Commands follow a RESTful Request/Response pattern, while state changes are broadcast via WebSockets.

### Workflow
1. **Mutation:** Client sends a REST request (`PATCH /reorder`).
2. **Authority:** Server validates, persists to DB, and returns the **Authoritative New Timestamp** in the response.
3. **Echo:** Server broadcasts a `playlist:track:reordered` event to all other users in the room.
4. **Resync:** Other clients receive the broadcast and apply the absolute position shifts from the `updates` array to their local state.

This hybrid approach leverages REST's robust error handling for the initiator and the WebSocket's speed for the collaborators.
