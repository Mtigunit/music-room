import 'package:equatable/equatable.dart';

import 'package:music_room/features/playlist/domain/entities/playlist_entity.dart';

abstract class PlaylistEvent extends Equatable {
  const PlaylistEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

class PlaylistOpened extends PlaylistEvent {
  const PlaylistOpened(this.playlistId);

  final String playlistId;

  @override
  List<Object?> get props => <Object?>[playlistId];
}

class PlaylistRefreshRequested extends PlaylistEvent {
  const PlaylistRefreshRequested();
}

class PlaylistAddTrackRequested extends PlaylistEvent {
  const PlaylistAddTrackRequested(this.track);

  final TrackSearchEntity track;

  @override
  List<Object?> get props => <Object?>[track];
}

class PlaylistRemoveTrackRequested extends PlaylistEvent {
  const PlaylistRemoveTrackRequested(this.playlistTrackId);

  final String playlistTrackId;

  @override
  List<Object?> get props => <Object?>[playlistTrackId];
}

class PlaylistReorderRequested extends PlaylistEvent {
  const PlaylistReorderRequested({
    required this.oldIndex,
    required this.newIndex,
  });

  final int oldIndex;
  final int newIndex;

  @override
  List<Object?> get props => <Object?>[oldIndex, newIndex];
}

class PlaylistConnectivityChanged extends PlaylistEvent {
  const PlaylistConnectivityChanged({required this.isOnline});

  final bool isOnline;

  @override
  List<Object?> get props => <Object?>[isOnline];
}

class PlaylistSocketConnected extends PlaylistEvent {
  const PlaylistSocketConnected();
}

class PlaylistSocketPayloadReceived extends PlaylistEvent {
  const PlaylistSocketPayloadReceived({
    required this.eventName,
    required this.payload,
  });

  final String eventName;
  final dynamic payload;

  @override
  List<Object?> get props => <Object?>[eventName, payload];
}

class PlaylistSyncErrorCleared extends PlaylistEvent {
  const PlaylistSyncErrorCleared();
}
