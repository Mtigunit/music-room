import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:music_room/core/config/app_config.dart';
import 'package:music_room/core/realtime/socket_client.dart';
import 'package:music_room/core/realtime/socket_events.dart';
import 'package:music_room/core/services/connectivity_service.dart';
import 'package:music_room/features/playlist/data/datasources/playlist_cache_datasource.dart';
import 'package:music_room/features/playlist/data/datasources/playlist_remote_datasource.dart';
import 'package:music_room/features/playlist/data/models/playlist_model.dart';
import 'package:music_room/features/playlist/domain/entities/playlist_entity.dart';
import 'package:music_room/features/playlist/presentation/state/playlist_event.dart';
import 'package:music_room/features/playlist/presentation/state/playlist_state.dart';

/// Maximum back-off cap for retry scheduling (seconds).
const int _kMaxRetrySeconds = 60;

class PlaylistBloc extends Bloc<PlaylistEvent, PlaylistState> {
  PlaylistBloc({
    required IPlaylistRemoteDataSource playlistRemoteDataSource,
    required IPlaylistCacheDataSource playlistCacheDataSource,
    required ConnectivityService connectivityService,
    required SocketClient socketClient,
  }) : _playlistRemoteDataSource = playlistRemoteDataSource,
       _playlistCacheDataSource = playlistCacheDataSource,
       _connectivityService = connectivityService,
       _socketClient = socketClient,
       super(const PlaylistState.initial()) {
    on<PlaylistOpened>(_onPlaylistOpened);
    on<PlaylistRefreshRequested>(_onPlaylistRefreshRequested);
    on<PlaylistAddTrackRequested>(_onPlaylistAddTrackRequested);
    on<PlaylistRemoveTrackRequested>(_onPlaylistRemoveTrackRequested);
    on<PlaylistReorderRequested>(_onPlaylistReorderRequested);
    on<PlaylistConnectivityChanged>(_onPlaylistConnectivityChanged);
    on<PlaylistSocketConnected>(_onPlaylistSocketConnected);
    on<PlaylistSocketPayloadReceived>(_onPlaylistSocketPayloadReceived);
    on<PlaylistSyncErrorCleared>(_onPlaylistSyncErrorCleared);

    // Re-join the active playlist room whenever the global socket
    // (re)connects.  ConnectivityService owns reconnectWithAuth(); this bloc
    // only reacts to the resulting connection event.
    _socketConnectedSub = socketClient.onConnected.listen(
      (_) => add(const PlaylistSocketConnected()),
    );
  }

  final IPlaylistRemoteDataSource _playlistRemoteDataSource;
  final IPlaylistCacheDataSource _playlistCacheDataSource;
  final ConnectivityService _connectivityService;
  final SocketClient _socketClient;

  StreamSubscription<bool>? _connectivitySubscription;
  // Manages the socket connected stream; reconnection is owned by
  // ConnectivityService.
  StreamSubscription<void>? _socketConnectedSub;
  Timer? _retryTimer;
  int _retryAttempt = 0;

  String? _activePlaylistId;

  // Event handlers

  Future<void> _onPlaylistOpened(
    PlaylistOpened event,
    Emitter<PlaylistState> emit,
  ) async {
    _activePlaylistId = event.playlistId;
    _retryTimer?.cancel();
    _retryAttempt = 0;

    emit(
      state.copyWith(
        status: PlaylistSyncStatus.loading,
        clearErrorMessage: true,
        isSyncing: false,
      ),
    );
    await _loadCachedSnapshot(event.playlistId, emit);

    // _setupConnectivityListener subscribes to the change stream and
    // immediately synthesises a PlaylistConnectivityChanged event.
    // This event uses the current connectivity status.
    // That event will drive the initial fetch (or offline display), so there is
    // no need to duplicate the isOnline() check and fetch here.
    await _setupConnectivityListener();
  }

  Future<void> _onPlaylistRefreshRequested(
    PlaylistRefreshRequested event,
    Emitter<PlaylistState> emit,
  ) async {
    if (state.isOffline) {
      _emitOfflineStatus(emit);
      return;
    }
    await _fetchAndReplace(emit, isReconnect: false);
  }

  Future<void> _onPlaylistAddTrackRequested(
    PlaylistAddTrackRequested event,
    Emitter<PlaylistState> emit,
  ) async {
    final playlistId = _activePlaylistId;
    if (state.playlist == null || playlistId == null) return;

    if (state.isOffline) {
      emit(state.copyWith(errorMessage: _kOfflineMessage));
      return;
    }

    try {
      final result = await _playlistRemoteDataSource.addTrackToPlaylist(
        playlistId,
        event.track,
      );
      await _applyTrackMutation(
        emit,
        updatedAt: result.newUpdatedAt,
        transform: (tracks) {
          tracks
            ..removeWhere(
              (track) =>
                  track.playlistTrackId == result.playlistTrack.playlistTrackId,
            )
            ..add(result.playlistTrack);
          return tracks;
        },
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 409) {
        emit(state.copyWith(errorMessage: _kConflictMessage));
        await _fetchAndReplace(emit, isReconnect: false);
        return;
      }
      emit(state.copyWith(errorMessage: 'Failed to add song to playlist.'));
    } on Object {
      emit(state.copyWith(errorMessage: 'Failed to add song to playlist.'));
    }
  }

  Future<void> _onPlaylistRemoveTrackRequested(
    PlaylistRemoveTrackRequested event,
    Emitter<PlaylistState> emit,
  ) async {
    final playlistId = _activePlaylistId;
    if (state.playlist == null || playlistId == null) return;

    if (state.isOffline) {
      emit(state.copyWith(errorMessage: _kOfflineMessage));
      return;
    }

    if (state.removingTrackIds.contains(event.playlistTrackId)) {
      return;
    }

    final removing = List<String>.from(state.removingTrackIds)
      ..add(event.playlistTrackId);
    emit(state.copyWith(removingTrackIds: removing));

    try {
      final result = await _playlistRemoteDataSource.removeTrackFromPlaylist(
        playlistId,
        event.playlistTrackId,
      );
      await _applyTrackMutation(
        emit,
        updatedAt: result.newUpdatedAt,
        transform: (tracks) {
          tracks.removeWhere(
            (track) =>
                track.playlistTrackId == result.deletedTrack.playlistTrackId,
          );
          return tracks;
        },
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 409) {
        emit(state.copyWith(errorMessage: _kConflictMessage));
        await _fetchAndReplace(emit, isReconnect: false);
        return;
      }
      emit(
        state.copyWith(errorMessage: 'Failed to remove song from playlist.'),
      );
    } on Object {
      emit(
        state.copyWith(errorMessage: 'Failed to remove song from playlist.'),
      );
    } finally {
      final updatedRemoving = List<String>.from(state.removingTrackIds)
        ..remove(event.playlistTrackId);
      emit(state.copyWith(removingTrackIds: updatedRemoving));
    }
  }

  Future<void> _onPlaylistReorderRequested(
    PlaylistReorderRequested event,
    Emitter<PlaylistState> emit,
  ) async {
    final playlist = state.playlist;
    final playlistId = _activePlaylistId;
    final latestUpdatedAt = state.latestUpdatedAt;

    if (playlist == null || playlistId == null) return;
    if (state.isOffline) {
      emit(state.copyWith(errorMessage: _kOfflineMessage));
      return;
    }
    if (state.isReordering) return;

    // Guard against an empty updatedAt before doing any optimistic work.
    if (latestUpdatedAt == null || latestUpdatedAt.isEmpty) {
      emit(state.copyWith(errorMessage: 'Failed to reorder songs.'));
      return;
    }

    final originalTracks = List<PlaylistTrackEntity>.from(playlist.tracks);

    final targetIndex = event.newIndex;
    final updatedTracks = List<PlaylistTrackEntity>.from(playlist.tracks);
    final movedTrack = updatedTracks.removeAt(event.oldIndex);
    updatedTracks.insert(targetIndex, movedTrack);
    final reindexedTracks = _reindexTracks(updatedTracks);

    final optimisticPlaylist = _playlistWithTracks(playlist, reindexedTracks);
    final (optimisticById, optimisticIds) = _normalizeTracks(reindexedTracks);

    emit(
      state.copyWith(
        playlist: optimisticPlaylist,
        tracksById: optimisticById,
        orderedTrackIds: optimisticIds,
        isReordering: true,
        clearErrorMessage: true,
      ),
    );

    try {
      final result = await _playlistRemoteDataSource.reorderPlaylistTracks(
        playlistId,
        movedTrack.playlistTrackId,
        targetIndex,
        latestUpdatedAt,
      );

      emit(
        state.copyWith(
          latestUpdatedAt: result.newUpdatedAt,
          isReordering: false,
        ),
      );

      await _savePlaylistToCache(
        playlist: optimisticPlaylist,
        updatedAt: result.newUpdatedAt,
      );
    } on PlaylistConflictException {
      _rollbackReorder(
        emit,
        playlist,
        originalTracks,
        error: _kConflictMessage,
        isSyncing: true,
      );
      await _fetchAndReplace(emit, isReconnect: false);
    } on Object {
      _rollbackReorder(
        emit,
        playlist,
        originalTracks,
        error: 'Failed to reorder songs.',
      );
    }
  }

  Future<void> _onPlaylistConnectivityChanged(
    PlaylistConnectivityChanged event,
    Emitter<PlaylistState> emit,
  ) async {
    if (!event.isOnline) {
      emit(state.copyWith(isOffline: true, errorMessage: _kOfflineMessage));
      return;
    }

    // Cancel any pending back-off retry — the fetch below replaces it.
    _retryTimer?.cancel();
    _retryAttempt = 0;

    emit(state.copyWith(isOffline: false, clearErrorMessage: true));

    // Reconnection is driven by ConnectivityService; only re-attach domain
    // listeners here so the bloc receives socket events after a network
    // restore, then fetch fresh data.
    _reattachSocketListeners();
    await _fetchAndReplace(emit, isReconnect: true);
  }

  Future<void> _onPlaylistSocketConnected(
    PlaylistSocketConnected event,
    Emitter<PlaylistState> emit,
  ) async {
    await _joinActivePlaylistRoom();
  }

  Future<void> _onPlaylistSocketPayloadReceived(
    PlaylistSocketPayloadReceived event,
    Emitter<PlaylistState> emit,
  ) async {
    final playlist = state.playlist;
    if (playlist == null || state.isOffline) return;

    final currentUpdatedAt = state.latestUpdatedAt ?? playlist.updatedAt;

    // Discard stale events whose updatedAt predates the current known state.
    final payloadUpdatedAt =
        _asUpdatedAt(
          (event.payload as Map<String, dynamic>?)?['newUpdatedAt'],
        ) ??
        _asUpdatedAt(
          (event.payload as Map<String, dynamic>?)?['updatedAt'],
        );
    if (payloadUpdatedAt != null &&
        payloadUpdatedAt.compareTo(currentUpdatedAt) <= 0) {
      return;
    }

    final updated = _applyRealtimePayload(
      playlist: playlist,
      eventName: event.eventName,
      payload: event.payload,
      currentUpdatedAt: currentUpdatedAt,
    );
    if (updated == null) return;

    final (byId, ids) = _normalizeTracks(updated.tracks);
    emit(
      state.copyWith(
        playlist: updated,
        tracksById: byId,
        orderedTrackIds: ids,
        latestUpdatedAt: updated.updatedAt,
        clearErrorMessage: true,
      ),
    );

    await _savePlaylistToCache(
      playlist: updated,
      updatedAt: updated.updatedAt,
    );
  }

  void _onPlaylistSyncErrorCleared(
    PlaylistSyncErrorCleared event,
    Emitter<PlaylistState> emit,
  ) {
    emit(state.copyWith(clearErrorMessage: true));
  }

  // Private helpers

  /// Emits the correct offline state depending on whether cached data exists.
  void _emitOfflineStatus(Emitter<PlaylistState> emit) {
    final hasCachedData = state.playlist != null;
    emit(
      state.copyWith(
        status: hasCachedData
            ? PlaylistSyncStatus.ready
            : PlaylistSyncStatus.error,
        isOffline: true,
        errorMessage: hasCachedData
            ? _kOfflineMessage
            : 'No cached data available offline',
      ),
    );
  }

  /// Reverts an optimistic reorder back to [originalTracks] and optionally
  /// marks the state as syncing.
  void _rollbackReorder(
    Emitter<PlaylistState> emit,
    PlaylistDetailsEntity playlist,
    List<PlaylistTrackEntity> originalTracks, {
    required String error,
    bool isSyncing = false,
  }) {
    final (byId, ids) = _normalizeTracks(originalTracks);
    emit(
      state.copyWith(
        playlist: _playlistWithTracks(playlist, originalTracks),
        tracksById: byId,
        orderedTrackIds: ids,
        isReordering: false,
        errorMessage: error,
        isSyncing: isSyncing,
      ),
    );
  }

  Future<void> _loadCachedSnapshot(
    String playlistId,
    Emitter<PlaylistState> emit,
  ) async {
    final snapshot = await _playlistCacheDataSource.getPlaylist(playlistId);
    if (snapshot == null) return;

    final (byId, ids) = _normalizeTracks(snapshot.playlist.tracks);
    emit(
      state.copyWith(
        status: PlaylistSyncStatus.ready,
        playlist: snapshot.playlist,
        tracksById: byId,
        orderedTrackIds: ids,
        latestUpdatedAt: snapshot.updatedAt,
        showStaleWarning: _isStale(snapshot.lastSyncedAt),
      ),
    );
  }

  Future<void> _fetchAndReplace(
    Emitter<PlaylistState> emit, {
    required bool isReconnect,
  }) async {
    final playlistId = _activePlaylistId;
    if (playlistId == null) return;

    emit(
      state.copyWith(
        isSyncing: isReconnect,
        status: state.playlist == null
            ? PlaylistSyncStatus.loading
            : PlaylistSyncStatus.ready,
      ),
    );

    try {
      final remote = await _playlistRemoteDataSource.fetchPlaylistDetails(
        playlistId,
      );
      final (byId, ids) = _normalizeTracks(remote.tracks);

      emit(
        state.copyWith(
          status: PlaylistSyncStatus.ready,
          playlist: remote,
          tracksById: byId,
          orderedTrackIds: ids,
          latestUpdatedAt: remote.updatedAt,
          isOffline: false,
          showStaleWarning: false,
          isSyncing: false,
          clearErrorMessage: true,
        ),
      );

      _retryAttempt = 0;
      await _savePlaylistToCache(playlist: remote, updatedAt: remote.updatedAt);
      await _joinActivePlaylistRoom();
    } on Object {
      emit(
        state.copyWith(
          isSyncing: false,
          status: state.playlist == null
              ? PlaylistSyncStatus.error
              : PlaylistSyncStatus.ready,
          errorMessage: 'Unable to sync. Showing last saved version.',
        ),
      );
      _scheduleRetry();
    }
  }

  Future<void> _savePlaylistToCache({
    required PlaylistDetailsEntity playlist,
    required String updatedAt,
  }) async {
    final playlistId = _activePlaylistId;
    if (playlistId == null) return;

    await _playlistCacheDataSource.savePlaylist(
      playlistId: playlistId,
      playlist: playlist,
      updatedAt: updatedAt,
      lastSyncedAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  /// Applies a local track-list mutation using the freshest playlist snapshot.
  Future<void> _applyTrackMutation(
    Emitter<PlaylistState> emit, {
    required String updatedAt,
    required List<PlaylistTrackEntity> Function(List<PlaylistTrackEntity>)
    transform,
  }) async {
    final currentPlaylist = state.playlist;
    if (currentPlaylist == null) return;

    final mutatedTracks = transform(
      List<PlaylistTrackEntity>.from(currentPlaylist.tracks),
    );
    final reindexedTracks = _reindexTracks(mutatedTracks);
    final updatedPlaylist = _playlistWithTracks(
      currentPlaylist,
      reindexedTracks,
      updatedAt: updatedAt,
    );
    final (byId, ids) = _normalizeTracks(reindexedTracks);

    emit(
      state.copyWith(
        playlist: updatedPlaylist,
        tracksById: byId,
        orderedTrackIds: ids,
        latestUpdatedAt: updatedAt,
        status: PlaylistSyncStatus.ready,
        clearErrorMessage: true,
      ),
    );

    await _savePlaylistToCache(
      playlist: updatedPlaylist,
      updatedAt: updatedAt,
    );
  }

  Future<void> _setupConnectivityListener() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivityService.isOnlineStream.listen((
      isOnline,
    ) {
      add(PlaylistConnectivityChanged(isOnline: isOnline));
    });

    // Immediately synthesise a connectivity event from the current status.
    // The stream only fires on *changes*, so without this the bloc stays in
    // whatever offline/online state it last saw if the user navigates away and
    // comes back while connectivity has since been restored.
    final isOnlineNow = await _connectivityService.isOnline();
    add(PlaylistConnectivityChanged(isOnline: isOnlineNow));
  }

  /// Re-attaches only domain-specific socket event listeners.
  ///
  /// The 'connect' lifecycle is handled via [SocketClient.onConnected]
  /// subscribed in the constructor — it must not be registered here to avoid
  /// duplicate handlers.
  void _reattachSocketListeners() {
    _detachSocketListeners();
    for (final event in const [
      SocketEvent.playlistTrackAdded,
      SocketEvent.playlistTrackRemoved,
      SocketEvent.playlistTrackReordered,
    ]) {
      _socketClient.on(event.value, (payload) {
        add(
          PlaylistSocketPayloadReceived(
            eventName: event.value,
            payload: payload,
          ),
        );
      });
    }
  }

  Future<void> _joinActivePlaylistRoom() async {
    final playlistId = _activePlaylistId;
    if (playlistId == null || !_socketClient.isConnected) return;
    _socketClient.emit('playlist:join', <String, dynamic>{
      'playlistId': playlistId,
    });
  }

  PlaylistDetailsEntity? _applyRealtimePayload({
    required PlaylistDetailsEntity playlist,
    required String eventName,
    required dynamic payload,
    required String currentUpdatedAt,
  }) {
    if (payload is! Map<String, dynamic>) return null;

    final payloadUpdatedAt =
        _asUpdatedAt(payload['newUpdatedAt']) ??
        _asUpdatedAt(payload['updatedAt']) ??
        currentUpdatedAt;

    if (eventName == SocketEvent.playlistTrackAdded.value) {
      final rawTrack = payload['track'];
      final trackPayload = rawTrack is Map<String, dynamic>
          ? rawTrack
          : payload;
      final entity = PlaylistTrackModel.fromJson(trackPayload).toEntity();
      final next = List<PlaylistTrackEntity>.from(playlist.tracks)
        ..removeWhere((t) => t.playlistTrackId == entity.playlistTrackId)
        ..add(entity)
        ..sort((a, b) => a.position.compareTo(b.position));
      return _playlistWithTracks(playlist, next, updatedAt: payloadUpdatedAt);
    }

    if (eventName == SocketEvent.playlistTrackRemoved.value) {
      final deletedTrackId = payload['deletedTrackId'];
      if (deletedTrackId is! String) return null;

      final next = playlist.tracks
          .where((t) => t.playlistTrackId != deletedTrackId)
          .toList();
      _applyPositionUpdates(next, payload['updates']);
      next.sort((a, b) => a.position.compareTo(b.position));
      return _playlistWithTracks(playlist, next, updatedAt: payloadUpdatedAt);
    }

    if (eventName == SocketEvent.playlistTrackReordered.value) {
      final updates = payload['updates'];
      if (updates is! List<dynamic>) return null;

      final next = List<PlaylistTrackEntity>.from(playlist.tracks);
      _applyPositionUpdates(next, updates);
      next.sort((a, b) => a.position.compareTo(b.position));
      return _playlistWithTracks(playlist, next, updatedAt: payloadUpdatedAt);
    }

    return null;
  }

  /// Applies a list of `{ trackId, position }` position-update objects from a
  /// socket payload onto [tracks] in-place.
  void _applyPositionUpdates(
    List<PlaylistTrackEntity> tracks,
    dynamic updates,
  ) {
    if (updates is! List<dynamic>) return;

    for (final update in updates) {
      if (update is! Map<String, dynamic>) continue;
      final trackId = update['trackId'];
      final position = update['position'];
      if (trackId is! String || position is! int) continue;

      final index = tracks.indexWhere((t) => t.playlistTrackId == trackId);
      if (index == -1) continue;

      final existing = tracks[index];
      tracks[index] = PlaylistTrackEntity(
        playlistTrackId: existing.playlistTrackId,
        providerTrackId: existing.providerTrackId,
        title: existing.title,
        durationMs: existing.durationMs,
        position: position,
        addedByUserId: existing.addedByUserId,
        artist: existing.artist,
        thumbnailUrl: existing.thumbnailUrl,
      );
    }
  }

  /// Returns a deduplicated, position-sorted `(byId, orderedIds)` pair.
  (Map<String, PlaylistTrackEntity>, List<String>) _normalizeTracks(
    List<PlaylistTrackEntity> tracks,
  ) {
    final sorted = List<PlaylistTrackEntity>.from(tracks)
      ..sort((a, b) => a.position.compareTo(b.position));

    final map = <String, PlaylistTrackEntity>{};
    final ids = <String>[];
    for (final track in sorted) {
      if (map.containsKey(track.playlistTrackId)) continue;
      map[track.playlistTrackId] = track;
      ids.add(track.playlistTrackId);
    }
    return (map, ids);
  }

  /// Rebuilds tracks so their `position` values match the list order.
  List<PlaylistTrackEntity> _reindexTracks(
    List<PlaylistTrackEntity> tracks,
  ) {
    return List<PlaylistTrackEntity>.generate(tracks.length, (index) {
      final track = tracks[index];
      return PlaylistTrackEntity(
        playlistTrackId: track.playlistTrackId,
        providerTrackId: track.providerTrackId,
        title: track.title,
        durationMs: track.durationMs,
        position: index,
        addedByUserId: track.addedByUserId,
        artist: track.artist,
        thumbnailUrl: track.thumbnailUrl,
      );
    });
  }

  PlaylistDetailsEntity _playlistWithTracks(
    PlaylistDetailsEntity base,
    List<PlaylistTrackEntity> tracks, {
    String? updatedAt,
  }) {
    return PlaylistDetailsEntity(
      id: base.id,
      name: base.name,
      ownerUserId: base.ownerUserId,
      visibility: base.visibility,
      editLicense: base.editLicense,
      description: base.description,
      collaboratorIds: base.collaboratorIds,
      tracks: tracks,
      tags: base.tags,
      updatedAt: updatedAt ?? base.updatedAt,
    );
  }

  String? _asUpdatedAt(dynamic value) {
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  bool _isStale(String lastSyncedAt) {
    final parsed = DateTime.tryParse(lastSyncedAt)?.toUtc();
    if (parsed == null) return false;
    const threshold = Duration(
      hours: AppConfig.stalePlaylistThresholdHours,
    );
    return DateTime.now().toUtc().difference(parsed) >= threshold;
  }

  /// Schedules an exponential back-off retry capped at [_kMaxRetrySeconds].
  ///
  /// Sequence (seconds): 1, 2, 4, 8, 16, 32, 60, 60, …
  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryAttempt += 1;
    final seconds = math.min(
      _retryAttempt == 1 ? 1 : 1 << (_retryAttempt - 1),
      _kMaxRetrySeconds,
    );
    _retryTimer = Timer(Duration(seconds: seconds), () {
      add(const PlaylistRefreshRequested());
    });
  }

  void _detachSocketListeners() {
    _socketClient
      ..off(SocketEvent.playlistTrackAdded.value)
      ..off(SocketEvent.playlistTrackRemoved.value)
      ..off(SocketEvent.playlistTrackReordered.value);
  }

  @override
  Future<void> close() async {
    // Cancel timer first so the queued PlaylistRefreshRequested event can
    // never fire after the bloc is closed.
    _retryTimer?.cancel();
    await _connectivitySubscription?.cancel();
    await _socketConnectedSub?.cancel();
    _detachSocketListeners();
    return super.close();
  }
}

// ─── Module-private string constants ─────────────────────────────────────────

const String _kOfflineMessage = 'You are offline. Playlist is read-only.';
const String _kConflictMessage = 'Playlist updated by someone else. Syncing...';
