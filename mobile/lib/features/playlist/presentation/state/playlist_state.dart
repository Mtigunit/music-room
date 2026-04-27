import 'package:equatable/equatable.dart';
import 'package:music_room/features/playlist/domain/entities/playlist_entity.dart';

enum PlaylistSyncStatus { initial, loading, ready, error }

class PlaylistState extends Equatable {
  const PlaylistState({
    required this.status,
    required this.playlist,
    required this.tracksById,
    required this.orderedTrackIds,
    required this.latestUpdatedAt,
    required this.isReordering,
    required this.isOffline,
    required this.showStaleWarning,
    required this.isSyncing,
    required this.currentUserId,
    required this.removingTrackIds,
    required this.errorMessage,
  });

  const PlaylistState.initial()
    : status = PlaylistSyncStatus.initial,
      playlist = null,
      tracksById = const <String, PlaylistTrackEntity>{},
      orderedTrackIds = const <String>[],
      latestUpdatedAt = null,
      isReordering = false,
      isOffline = false,
      showStaleWarning = false,
      isSyncing = false,
      currentUserId = null,
      removingTrackIds = const <String>[],
      errorMessage = null;

  final PlaylistSyncStatus status;
  final PlaylistDetailsEntity? playlist;
  final Map<String, PlaylistTrackEntity> tracksById;
  final List<String> orderedTrackIds;
  final String? latestUpdatedAt;
  final bool isReordering;
  final bool isOffline;
  final bool showStaleWarning;
  final bool isSyncing;
  final String? currentUserId;
  final List<String> removingTrackIds;
  final String? errorMessage;

  PlaylistState copyWith({
    PlaylistSyncStatus? status,
    PlaylistDetailsEntity? playlist,
    bool clearPlaylist = false,
    Map<String, PlaylistTrackEntity>? tracksById,
    List<String>? orderedTrackIds,
    String? latestUpdatedAt,
    bool clearLatestUpdatedAt = false,
    bool? isReordering,
    bool? isOffline,
    bool? showStaleWarning,
    bool? isSyncing,
    String? currentUserId,
    bool clearCurrentUserId = false,
    List<String>? removingTrackIds,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return PlaylistState(
      status: status ?? this.status,
      playlist: clearPlaylist ? null : (playlist ?? this.playlist),
      tracksById: tracksById ?? this.tracksById,
      orderedTrackIds: orderedTrackIds ?? this.orderedTrackIds,
      latestUpdatedAt: clearLatestUpdatedAt
          ? null
          : (latestUpdatedAt ?? this.latestUpdatedAt),
      isReordering: isReordering ?? this.isReordering,
      isOffline: isOffline ?? this.isOffline,
      showStaleWarning: showStaleWarning ?? this.showStaleWarning,
      isSyncing: isSyncing ?? this.isSyncing,
      currentUserId: clearCurrentUserId
          ? null
          : (currentUserId ?? this.currentUserId),
      removingTrackIds: removingTrackIds ?? this.removingTrackIds,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    playlist,
    tracksById,
    orderedTrackIds,
    latestUpdatedAt,
    isReordering,
    isOffline,
    showStaleWarning,
    isSyncing,
    currentUserId,
    removingTrackIds,
    errorMessage,
  ];
}
