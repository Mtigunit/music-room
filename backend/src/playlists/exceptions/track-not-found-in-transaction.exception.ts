/**
 * Thrown by the repository layer when a PlaylistTrack cannot be found
 * inside an active database transaction (e.g. during reorder).
 */
export class TrackNotFoundInTransactionException extends Error {
  constructor() {
    super('Track not found inside transaction.');
    this.name = 'TrackNotFoundInTransactionException';
  }
}
