enum SocketEvent {
  connected,
  disconnected,
  playlistTrackAdded,
  playlistTrackRemoved,
  playlistTrackReordered,
}

extension SocketEventName on SocketEvent {
  String get value {
    switch (this) {
      case SocketEvent.connected:
        return 'connect';
      case SocketEvent.disconnected:
        return 'disconnect';
      case SocketEvent.playlistTrackAdded:
        return 'playlist:track:added';
      case SocketEvent.playlistTrackRemoved:
        return 'playlist:track:removed';
      case SocketEvent.playlistTrackReordered:
        return 'playlist:track:reordered';
    }
  }
}
