/**
 * Thrown by the repository layer when an Optimistic Concurrency Control (OCC)
 * check fails — the client's baseUpdatedAt timestamp does not match the
 * current database value, indicating another transaction committed first.
 */
export class OccStaleException extends Error {
  constructor() {
    super('Playlist has been modified by another transaction.');
    this.name = 'OccStaleException';
  }
}
