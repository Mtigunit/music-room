/**
 * Thrown by the repository layer when a PlaylistTrack cannot be found
 * inside an active database transaction (e.g. during reorder).
 */
export class TrackNotFoundInTransactionException extends Error {
  constructor(message: string = 'Track not found inside transaction.') {
    super(message);
    this.name = 'TrackNotFoundInTransactionException';
  }
}
