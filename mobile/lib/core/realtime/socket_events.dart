enum SocketEvent {
  connected,
  disconnected,
  playlistTrackAdded,
  playlistTrackRemoved,
  playlistTrackReordered,

  eventJoin,
  eventHostJoin,
  eventStart,
  eventEnd,
  eventStatus,
  eventStarted,
  eventEnded,
  eventCount,
  eventLeave,
  eventHostLeave,
  hostSoftDisconnect,
  hostReconnected,
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
      case SocketEvent.eventJoin:
        return 'event:join';
      case SocketEvent.eventHostJoin:
        return 'event:host_join';
      case SocketEvent.eventStart:
        return 'event:start';
      case SocketEvent.eventEnd:
        return 'event:end';
      case SocketEvent.eventStatus:
        return 'event:status';
      case SocketEvent.eventStarted:
        return 'event:started';
      case SocketEvent.eventEnded:
        return 'event:ended';
      case SocketEvent.eventCount:
        return 'event:count';
      case SocketEvent.eventLeave:
        return 'event:leave';
      case SocketEvent.eventHostLeave:
        return 'event:host_leave';
      case SocketEvent.hostSoftDisconnect:
        return 'event:host_soft_disconnect';
      case SocketEvent.hostReconnected:
        return 'event:host_reconnected';
    }
  }
}
