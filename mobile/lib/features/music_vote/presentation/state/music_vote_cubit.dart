import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/realtime/socket_client.dart';
import 'package:music_room/core/realtime/socket_events.dart';
import 'package:music_room/core/services/delegation_gateway.dart';
import 'package:music_room/features/music_vote/data/models/event_detail_model.dart';
import 'package:music_room/features/music_vote/data/models/event_track_model.dart';
import 'package:music_room/features/music_vote/domain/repositories/music_vote_repository.dart';

enum HostConnectionStatus { disconnected, reconnected }

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class MusicVoteState {
  const MusicVoteState({
    this.isLoading = false,
    this.isAddingTrack = false,
    this.isStartingEvent = false,
    this.isEndingEvent = false,
    this.isAudioLoading = false,
    this.isJoinFailed = false,
    this.error,
    this.successMessage,
    this.event,
    this.tracks = const [],
    this.listenerCount,
    this.hostConnectionStatus,
    this.currentTrack,
    this.playbackStatus,
  });

  final bool isLoading;
  final bool isAddingTrack;
  final bool isStartingEvent;
  final bool isEndingEvent;

  /// `true` while the audio engine is resolving / buffering the track.
  /// The UI must NOT start the progress ticker or show "playing" controls
  /// until this is `false`.
  final bool isAudioLoading;
  final bool isJoinFailed;
  final String? error;
  final String? successMessage;
  final EventDetailModel? event;
  final List<EventTrackModel> tracks;
  final int? listenerCount;
  final HostConnectionStatus? hostConnectionStatus;

  /// The track currently playing in the room. `null` when the queue is
  /// empty or playback has not started. Pushed from `playback:status`.
  final EventTrackModel? currentTrack;

  /// 'PLAYING' or 'PAUSED'. `null` until the first `playback:status`.
  final String? playbackStatus;

  MusicVoteState copyWith({
    bool? isLoading,
    bool? isAddingTrack,
    bool? isStartingEvent,
    bool? isEndingEvent,
    bool? isAudioLoading,
    bool? isJoinFailed,
    String? error,
    String? successMessage,
    EventDetailModel? event,
    List<EventTrackModel>? tracks,
    int? listenerCount,
    HostConnectionStatus? hostConnectionStatus,
    EventTrackModel? currentTrack,
    String? playbackStatus,
    bool clearError = false,
    bool clearSuccessMessage = false,
    bool clearCurrentTrack = false,
  }) {
    return MusicVoteState(
      isLoading: isLoading ?? this.isLoading,
      isAddingTrack: isAddingTrack ?? this.isAddingTrack,
      isStartingEvent: isStartingEvent ?? this.isStartingEvent,
      isEndingEvent: isEndingEvent ?? this.isEndingEvent,
      isAudioLoading: isAudioLoading ?? this.isAudioLoading,
      isJoinFailed: isJoinFailed ?? this.isJoinFailed,
      error: clearError ? null : (error ?? this.error),
      successMessage: clearSuccessMessage
          ? null
          : (successMessage ?? this.successMessage),
      event: event ?? this.event,
      tracks: tracks ?? this.tracks,
      listenerCount: listenerCount ?? this.listenerCount,
      hostConnectionStatus: hostConnectionStatus ?? this.hostConnectionStatus,
      currentTrack: clearCurrentTrack
          ? null
          : (currentTrack ?? this.currentTrack),
      playbackStatus: playbackStatus ?? this.playbackStatus,
    );
  }
}

// ---------------------------------------------------------------------------
// Cubit
// ---------------------------------------------------------------------------

class MusicVoteCubit extends Cubit<MusicVoteState> {
  MusicVoteCubit({
    required MusicVoteRepository repository,
    required SocketClient socketClient,
    DelegationGateway? delegationGateway,
    String? userId,
  }) : _repository = repository,
       _socketClient = socketClient,
       _delegationGateway = delegationGateway,
       _currentUserId = userId,
       super(const MusicVoteState()) {
    // Re-join the event room whenever the global socket (re)connects.
    // ConnectivityService is the sole owner of reconnectWithAuth(); this
    // cubit only reacts to the resulting connection event.
    _socketConnectedSub = socketClient.onConnected.listen((_) {
      _hasJoinedLiveRoom = false;
      unawaited(_joinEventRoom());
    });
    // Clear the join flag on disconnect so the next onConnected fires a
    // fresh join instead of being blocked by a stale true value.
    _socketDisconnectedSub = socketClient.onDisconnected.listen((_) {
      _hasJoinedLiveRoom = false;
    });

    // When the local user accepts a delegation, the backend flips the
    // event's `isDelegated` flag server-side. Re-fetch the event details
    // so the UI unlocks playback controls (no extra round-trip required
    // from the popup itself).
    final gateway = _delegationGateway;
    if (gateway != null) {
      _delegationAcceptedSub = gateway.acceptedDelegations.listen(
        _handleDelegationAccepted,
      );
      _delegationRemovedSub = gateway.removedDelegations.listen(
        _handleDelegationRemoved,
      );
    }
  }

  final MusicVoteRepository _repository;
  final SocketClient _socketClient;
  final DelegationGateway? _delegationGateway;

  String? _activeEventId;
  bool _socketListenersAttached = false;
  bool _hasJoinedLiveRoom = false;

  // ── Socket lifecycle subscriptions (reconnect in ConnectivityService) ──
  StreamSubscription<void>? _socketConnectedSub;
  StreamSubscription<void>? _socketDisconnectedSub;
  StreamSubscription<DelegationInvite>? _delegationAcceptedSub;
  StreamSubscription<Map<String, dynamic>>? _delegationRemovedSub;

  /// Tracks in-flight vote attempts: trackId → intended voteType ('up'|'none').
  /// The UI is NOT updated until the server confirms via [track:vote_updated].
  final Map<String, String> _pendingVotes = {};

  bool _isWaitingForNextPlay = false;

  final String? _currentUserId;

  /// Host-side auto-advance timer: fires `playback:next` when the current
  /// track reaches the end of its duration. Cancelled on pause / next /
  /// new status / close.
  Timer? _autoAdvanceTimer;

  /// Whether the current user is the host of the active event.
  bool get _isHost {
    final event = state.event;
    final hostId = event?.hostId;
    return (event?.isHost ?? false) ||
        (hostId != null && hostId.isNotEmpty && hostId == _currentUserId);
  }

  /// Whether the current user has playback delegation for this event.
  ///
  /// `isDelegated` is hydrated by `GET /events/{id}` on join; the backend
  /// flips it to `true` once the delegatee accepts via socket. The cubit
  /// re-reads it through `_canControlPlayback` so playback controls remain
  /// scoped to host **or** delegated users.
  bool get _isDelegated => state.event?.isDelegated ?? false;

  /// Whether the current user is allowed to issue playback control events
  /// (`play`, `pause`, `next`). Hosts always qualify; delegated guests
  /// qualify once their delegation has been accepted on the backend.
  bool get _canControlPlayback => _isHost || _isDelegated;

  /// Loads the event details and queued tracks concurrently.
  ///
  /// Socket reconnection is NOT triggered here — `ConnectivityService` owns
  /// that responsibility.  This method attaches domain listeners and attempts
  /// a room join if the socket is already connected; if not, the
  /// `onConnected` subscription (set up in the constructor) will join once the
  /// socket comes online.
  Future<void> loadRoom(String eventId) async {
    _activeEventId = eventId;
    _hasJoinedLiveRoom = false;
    emit(state.copyWith(isLoading: true, clearError: true));

    // Attach domain-specific socket event listeners. Reconnection is handled
    // globally by ConnectivityService — never call reconnectWithAuth() here.
    _attachSocketListeners();

    try {
      final results = await Future.wait([
        _repository.getEventDetails(eventId),
        _repository.getEventTracks(eventId),
      ]);

      if (isClosed) return;

      final event = results[0] as EventDetailModel;
      final tracks = List<EventTrackModel>.from(
        results[1] as List<EventTrackModel>,
      );

      _sortTracks(tracks);

      emit(
        state.copyWith(
          isLoading: event.status == 'LIVE',
          event: event,
          tracks: tracks,
          isJoinFailed: false,
          // Seed playback state from the REST response so the PlayerCard
          // shows the correct track immediately on join / re-join, before
          // the first playback:status socket event arrives.
          currentTrack: event.currentTrack,
          playbackStatus: event.playbackStatus,
          clearCurrentTrack: event.currentTrack == null,
        ),
      );

      await _joinEventRoom();
    } on DioException catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          error: _extractDioMessage(e),
        ),
      );
    } on Object {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Unable to load room data.',
        ),
      );
    }
  }

  /// Appends a track to the event queue, then re-fetches
  /// all tracks to guarantee the UI shows the correct
  /// vote-sorted order from the server.
  Future<void> addTrack(String eventId, String providerTrackId) async {
    emit(state.copyWith(isAddingTrack: true, clearError: true));

    try {
      await _repository.addTrack(eventId, providerTrackId);

      if (isClosed) return;

      // Re-fetch to get the server's canonical ordering.
      final fetchedTracks = await _repository.getEventTracks(eventId);
      final tracks = List<EventTrackModel>.from(fetchedTracks);
      _sortTracks(tracks);

      if (isClosed) return;

      emit(state.copyWith(isAddingTrack: false, tracks: tracks));
    } on DioException catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isAddingTrack: false,
          error: _extractDioMessage(e),
        ),
      );
    } on Object {
      if (isClosed) return;
      emit(
        state.copyWith(
          isAddingTrack: false,
          error: 'Unable to add track.',
        ),
      );
    }
  }

  /// Removes a track from the event queue and optimistically updates the
  /// local state.
  Future<void> removeTrack(String eventId, String providerTrackId) async {
    try {
      await _repository.removeTrack(eventId, providerTrackId);

      if (isClosed) return;

      // Optimistically update the local state: filter out the removed track.
      final updatedTracks = state.tracks
          .where((t) => t.providerTrackId != providerTrackId)
          .toList();

      emit(state.copyWith(tracks: updatedTracks, clearError: true));
    } on DioException catch (e) {
      if (isClosed) return;
      emit(state.copyWith(error: _extractDioMessage(e)));
    } on Object {
      if (isClosed) return;
      emit(state.copyWith(error: 'Unable to remove track.'));
    }
  }

  /// Transitions the event from UPCOMING → LIVE.
  ///
  Future<void> startEvent(String eventId) async {
    if (state.isStartingEvent) return;
    emit(state.copyWith(isStartingEvent: true, clearError: true));

    _activeEventId = eventId;
    _attachSocketListeners();

    if (!_socketClient.isConnected) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isStartingEvent: false,
          error: 'Unable to connect to live updates.',
        ),
      );
      return;
    }

    try {
      debugPrint(
        '🚀 [MusicVoteCubit] Emitting: eventStart for eventId: $eventId',
      );
      _socketClient.emit(SocketEvent.eventStart.value, <String, dynamic>{
        'eventId': eventId,
      });
    } on Object {
      if (isClosed) return;
      emit(
        state.copyWith(
          isStartingEvent: false,
          error: 'Unable to start event.',
        ),
      );
    }
  }

  /// Transitions the event from LIVE → ENDED.
  ///
  Future<bool> endEvent(String eventId) async {
    if (state.isEndingEvent) return false;
    emit(state.copyWith(isEndingEvent: true, clearError: true));

    _activeEventId = eventId;
    _attachSocketListeners();

    if (!_socketClient.isConnected) {
      if (isClosed) return false;
      emit(
        state.copyWith(
          isEndingEvent: false,
          error: 'Unable to connect to live updates.',
        ),
      );
      return false;
    }

    try {
      debugPrint(
        '🚀 [MusicVoteCubit] Emitting: eventEnd for eventId: $eventId',
      );
      _socketClient.emit(SocketEvent.eventEnd.value, <String, dynamic>{
        'eventId': eventId,
      });
      return true;
    } on Object {
      if (isClosed) return false;
      emit(
        state.copyWith(
          isEndingEvent: false,
          error: 'Unable to end event.',
        ),
      );
      return false;
    }
  }

  /// Manually leave the event room.
  void leaveEvent(String eventId) {
    if (eventId.isEmpty || !_socketClient.isConnected) return;

    final eventName = _isHost
        ? SocketEvent.eventHostLeave.value
        : SocketEvent.eventLeave.value;

    debugPrint(
      '🚀 [MusicVoteCubit] Emitting: $eventName for eventId: $eventId',
    );
    _socketClient.emit(eventName, <String, dynamic>{'eventId': eventId});
  }

  void voteTrack({
    required String trackId,
    required String voteType,
    double? lat,
    double? lng,
  }) {
    if (voteType != 'up' && voteType != 'none') {
      return;
    }

    final eventId = _activeEventId ?? state.event?.id;
    if (eventId == null || eventId.isEmpty) return;

    // Store the pending vote intention — the UI will only update
    // when the server confirms via track:vote_updated.
    _pendingVotes[trackId] = voteType;

    final payload = <String, dynamic>{
      'eventId': eventId,
      'trackId': trackId,
      'vote': voteType,
      'locationLat': ?lat,
      'locationLng': ?lng,
    };

    _socketClient.emit(SocketEvent.trackVote.value, payload);
    debugPrint(
      '🚀 [MusicVoteCubit] Emitting: track:vote with payload: $payload',
    );
  }

  /// Attaches domain-specific socket event listeners.
  ///
  /// The 'connect' lifecycle event is handled via [SocketClient.onConnected]
  /// (subscribed in the constructor) — it must not be registered here to
  /// avoid duplicate handlers and to guarantee it fires even when this method
  /// hasn't been called yet.
  void _attachSocketListeners() {
    _detachSocketListeners();
    _socketClient
      ..on(SocketEvent.eventStarted.value, _handleEventStarted)
      ..on(SocketEvent.eventEnded.value, _handleEventEnded)
      ..on(SocketEvent.eventStatus.value, _handleEventStatus)
      ..on(SocketEvent.eventCount.value, _handleEventCount)
      ..on(SocketEvent.hostSoftDisconnect.value, _handleHostSoftDisconnect)
      ..on(SocketEvent.hostReconnected.value, _handleHostReconnected)
      ..on(SocketEvent.trackAdded.value, _handleTrackAdded)
      ..on(SocketEvent.trackRemoved.value, _handleTrackRemoved)
      ..on(SocketEvent.trackVoteUpdated.value, _handleTrackVoteUpdated)
      ..on(SocketEvent.playbackStatus.value, _handlePlaybackStatus)
      ..on(SocketEvent.exception.value, _handleSocketException);
    _socketListenersAttached = true;
  }

  void _detachSocketListeners() {
    if (!_socketListenersAttached) return;
    _socketClient
      ..off(SocketEvent.eventStarted.value)
      ..off(SocketEvent.eventEnded.value)
      ..off(SocketEvent.eventStatus.value)
      ..off(SocketEvent.eventCount.value)
      ..off(SocketEvent.hostSoftDisconnect.value)
      ..off(SocketEvent.hostReconnected.value)
      ..off(SocketEvent.trackAdded.value)
      ..off(SocketEvent.trackRemoved.value)
      ..off(SocketEvent.trackVoteUpdated.value)
      ..off(SocketEvent.playbackStatus.value)
      ..off(SocketEvent.exception.value);
    _socketListenersAttached = false;
  }

  void _handleEventStarted(dynamic payload) {
    debugPrint(
      '📡 [MusicVoteCubit] Received: eventStarted with payload: $payload',
    );
    if (!_isRelevantEventPayload(payload)) return;
    final status = _extractStatus(payload) ?? 'LIVE';
    final startDate = _extractStartDate(payload);
    _applyEventStatus(status, startDate: startDate);
  }

  void _handleEventEnded(dynamic payload) {
    debugPrint(
      '📡 [MusicVoteCubit] Received: eventEnded with payload: $payload',
    );
    if (!_isRelevantEventPayload(payload)) return;

    final eventId = _activeEventId ?? state.event?.id;
    if (eventId != null && eventId.isNotEmpty) {
      leaveEvent(eventId);
    }

    _applyEventStatus('ENDED');
  }

  void _handleEventStatus(dynamic payload) {
    debugPrint(
      '📡 [MusicVoteCubit] Received: eventStatus with payload: $payload',
    );
    if (!_isRelevantEventPayload(payload)) return;
    final status = _extractStatus(payload);
    if (status == null) return;
    final startDate = _extractStartDate(payload);
    _applyEventStatus(status, startDate: startDate);
  }

  void _handleEventCount(dynamic payload) {
    debugPrint(
      '📡 [MusicVoteCubit] Received: eventCount with payload: $payload',
    );
    if (!_isRelevantEventPayload(payload)) return;
    if (payload is Map<String, dynamic>) {
      final count = payload['count'];
      if (count is int) {
        emit(state.copyWith(listenerCount: count));
      }
    }
  }

  void _handleHostSoftDisconnect(dynamic payload) {
    debugPrint(
      '📡 [MusicVoteCubit] Received: hostSoftDisconnect payload: $payload',
    );
    if (!_isRelevantEventPayload(payload)) return;
    emit(
      state.copyWith(hostConnectionStatus: HostConnectionStatus.disconnected),
    );
  }

  void _handleHostReconnected(dynamic payload) {
    debugPrint(
      '📡 [MusicVoteCubit] Received: hostReconnected payload: $payload',
    );
    if (!_isRelevantEventPayload(payload)) return;
    emit(
      state.copyWith(hostConnectionStatus: HostConnectionStatus.reconnected),
    );
  }

  void _handleTrackAdded(dynamic payload) {
    debugPrint(
      '📡 [MusicVoteCubit] Received: trackAdded with payload: $payload',
    );
    if (!_isRelevantEventPayload(payload)) return;
    if (payload is! Map<String, dynamic>) return;

    try {
      final newTrack = EventTrackModel.fromJson(payload);

      // Prevent duplicate additions (Check by providerTrackId to be safe)
      final exists = state.tracks.any(
        (t) =>
            t.providerTrackId == newTrack.providerTrackId ||
            t.id == newTrack.id,
      );
      if (exists) return;

      // Append to the bottom of the list
      final updatedTracks = List<EventTrackModel>.from(state.tracks)
        ..add(newTrack);

      _sortTracks(updatedTracks);

      emit(state.copyWith(tracks: updatedTracks));
    } on Object {
      // Silent ignore for malformed payload
    }
  }

  void _handleTrackRemoved(dynamic payload) {
    debugPrint(
      '📡 [MusicVoteCubit] Received: trackRemoved with payload: $payload',
    );
    if (!_isRelevantEventPayload(payload)) return;
    if (payload is! Map<String, dynamic>) return;

    final providerTrackId = payload['providerTrackId'];
    if (providerTrackId is! String || providerTrackId.isEmpty) return;

    final updatedTracks = state.tracks
        .where((t) => t.providerTrackId != providerTrackId)
        .toList();

    // Best Practice: Only emit if the list actually changed to prevent
    // UI flicker
    if (updatedTracks.length != state.tracks.length) {
      emit(state.copyWith(tracks: updatedTracks));
    }
  }

  void _handlePlaybackStatus(dynamic payload) {
    debugPrint(
      '📡 [MusicVoteCubit] Received: playbackStatus with payload: $payload',
    );
    if (!_isRelevantEventPayload(payload)) return;
    if (payload is! Map<String, dynamic>) return;

    final status = payload['status'];
    final rawTrack = payload['currentTrack'];

    EventTrackModel? newTrack;
    var clearTrack = false;
    if (rawTrack is Map<String, dynamic>) {
      try {
        newTrack = EventTrackModel.fromJson(rawTrack);
      } on Object {
        newTrack = null;
      }
    } else if (rawTrack == null && payload.containsKey('currentTrack')) {
      // Explicit null from backend → queue empty.
      clearTrack = true;
    }

    // Remove the previous track from the queue when the current track
    // actually changes (i.e. a new song started, not just pause/resume,
    // or the playlist finishes and is cleared).
    final previousTrack = state.currentTrack;
    final shouldRemovePrevious =
        previousTrack != null &&
        ((newTrack != null && previousTrack.id != newTrack.id) ||
            (newTrack == null && clearTrack));

    var updatedTracks = state.tracks;
    if (shouldRemovePrevious) {
      updatedTracks = state.tracks
          .where((t) => t.id != previousTrack.id)
          .toList();
    }

    // Re-sort so the new current track is pinned to the top immediately.
    final sortedTracks = List<EventTrackModel>.from(updatedTracks);
    _sortTracks(sortedTracks);

    if (shouldRemovePrevious && newTrack != null && _isHost) {
      _isWaitingForNextPlay = true;
    }

    if (status == 'PLAYING' && !_isHost) {
      setAudioLoading(isLoading: false);
    }

    if (newTrack == null) {
      _isWaitingForNextPlay = false;
      setAudioLoading(isLoading: false);
    }

    if (isClosed) return;

    emit(
      state.copyWith(
        playbackStatus: status is String && status.isNotEmpty ? status : null,
        currentTrack: newTrack,
        clearCurrentTrack: clearTrack,
        tracks: sortedTracks,
      ),
    );

    _schedulePlaybackAutoAdvance();
  }

  void _handleTrackVoteUpdated(dynamic payload) {
    debugPrint(
      '📡 [MusicVoteCubit] Received: trackVoteUpdated with payload: $payload',
    );
    if (!_isRelevantEventPayload(payload)) return;
    if (payload is! Map<String, dynamic>) return;

    try {
      final trackId = payload['trackId'];
      final score = payload['score'];

      if (trackId is! String || score is! int) {
        return;
      }

      final trackIndex = state.tracks.indexWhere((t) => t.trackId == trackId);
      if (trackIndex == -1) {
        _pendingVotes.remove(trackId);
        return;
      }

      final updatedTracks = List<EventTrackModel>.from(state.tracks);

      // If there is a pending vote from the current user for this track,
      // apply the isVoted state now that the server has confirmed the score.
      final pendingVote = _pendingVotes.remove(trackId);
      if (pendingVote != null) {
        updatedTracks[trackIndex] = updatedTracks[trackIndex].copyWith(
          voteScore: score,
          isVoted: pendingVote == 'up',
        );
      } else {
        updatedTracks[trackIndex] = updatedTracks[trackIndex].copyWith(
          voteScore: score,
        );
      }

      _sortTracks(updatedTracks);

      emit(state.copyWith(tracks: updatedTracks));
    } on Object {
      // Silent ignore for malformed payload
    }
  }

  bool _isRelevantEventPayload(dynamic payload) {
    if (payload is! Map<String, dynamic>) return true;
    final payloadEventId = payload['eventId'];
    if (payloadEventId is! String || payloadEventId.isEmpty) return true;
    final activeId = _activeEventId ?? state.event?.id;
    return activeId == null || activeId == payloadEventId;
  }

  String? _extractStatus(dynamic payload) {
    if (payload is! Map<String, dynamic>) return null;
    final status = payload['status'];
    return status is String && status.isNotEmpty ? status : null;
  }

  DateTime? _extractStartDate(dynamic payload) {
    if (payload is! Map<String, dynamic>) return null;
    final raw = payload['startDate'];
    if (raw is DateTime) return raw;
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  void _applyEventStatus(String status, {DateTime? startDate}) {
    final current = state.event;
    if (current == null) return;

    final updated = current.copyWith(
      status: status,
      startDate: startDate ?? current.startDate,
    );

    emit(
      state.copyWith(
        isLoading: false,
        event: updated,
        isStartingEvent:
            status != 'LIVE' && status != 'ENDED' && state.isStartingEvent,
        isEndingEvent: status != 'ENDED' && state.isEndingEvent,
        clearError: true,
      ),
    );
  }

  void _sortTracks(List<EventTrackModel> tracks) {
    final currentId = state.currentTrack?.id;
    tracks.sort((a, b) {
      // Pin the currently playing track to the top, regardless of vote score.
      if (currentId != null) {
        if (a.id == currentId) return -1;
        if (b.id == currentId) return 1;
      }
      // All other tracks sort by voteScore descending.
      final voteDiff = b.voteScore.compareTo(a.voteScore);
      if (voteDiff != 0) return voteDiff;
      // Tie-breaker: stable lexicographical order by id.
      return a.id.compareTo(b.id);
    });
  }

  Future<void> _joinEventRoom() async {
    debugPrint(
      'DEBUG: _joinEventRoom called — '
      '_hasJoinedLiveRoom=$_hasJoinedLiveRoom '
      'event=${state.event?.id} '
      'status=${state.event?.status} '
      'socketConnected=${_socketClient.isConnected}',
    );

    if (_hasJoinedLiveRoom) {
      return;
    }
    final event = state.event;
    if (event == null) {
      return;
    }
    if (event.status != 'LIVE') {
      if (_isHost || event.status == 'ENDED') {
        return;
      }
    }
    final eventId = _activeEventId ?? event.id;
    if (eventId.isEmpty) {
      return;
    }
    if (!_socketClient.isConnected) {
      return;
    }

    final eventName = _isHost
        ? SocketEvent.eventHostJoin.value
        : SocketEvent.eventJoin.value;

    debugPrint(
      '🚀 [MusicVoteCubit] Emitting: $eventName for eventId: $eventId',
    );
    _socketClient.emit(eventName, <String, dynamic>{'eventId': eventId});
    _hasJoinedLiveRoom = true;
  }

  String _extractDioMessage(DioException exception) {
    final data = exception.response?.data;

    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }

      if (message is List) {
        final messages = message.whereType<String>().toList(growable: false);
        if (messages.isNotEmpty) {
          return messages.join('\n');
        }
      }
    }

    if (exception.message != null && exception.message!.trim().isNotEmpty) {
      return exception.message!;
    }

    return 'A network error occurred.';
  }

  void setError(String message) {
    if (!isClosed) {
      emit(state.copyWith(error: message));
    }
  }

  void clearError() {
    if (!isClosed) {
      emit(state.copyWith(clearError: true));
    }
  }

  void clearSuccessMessage() {
    if (!isClosed) {
      emit(state.copyWith(clearSuccessMessage: true));
    }
  }

  /// Called by the audio phase listener in the View layer to reflect the
  /// actual audio-engine readiness in the cubit state.
  ///
  /// When `isLoading` is `true` the PlayerCard suppresses the progress
  /// ticker and shows a loading indicator on the play button.
  void setAudioLoading({required bool isLoading}) {
    if (isClosed) return;
    if (state.isAudioLoading == isLoading) return;
    emit(state.copyWith(isAudioLoading: isLoading));
  }

  /// Re-fetches the event details and merges the latest snapshot into
  /// the state. Used after the local user accepts a delegation so the
  /// `isDelegated` flag flips to `true` and playback controls unlock.
  Future<void> refreshEventDetails() async {
    final eventId = _activeEventId ?? state.event?.id;
    if (eventId == null || eventId.isEmpty) return;
    try {
      final event = await _repository.getEventDetails(eventId);
      if (isClosed) return;
      emit(state.copyWith(event: event));
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('⚠️ [MusicVoteCubit] refreshEventDetails failed: $error');
      }
    }
  }

  void _handleDelegationAccepted(DelegationInvite invite) {
    final active = _activeEventId ?? state.event?.id;
    if (active == null || active.isEmpty) return;
    if (invite.eventId != active) return;
    unawaited(refreshEventDetails());
  }

  void _handleDelegationRemoved(Map<String, dynamic> payload) {
    if (isClosed) return;
    final active = _activeEventId ?? state.event?.id;
    if (active == null || active.isEmpty) return;

    final eventId = payload['eventId'] as String? ?? '';
    if (eventId != active) return;

    // Immediately clear delegation permission and update UI in real-time
    final currentEvent = state.event;
    if (currentEvent != null) {
      final msg =
          payload['message'] as String? ?? 'Host removed delegation for you';
      emit(
        state.copyWith(
          event: currentEvent.copyWith(isDelegated: false),
          successMessage: msg,
        ),
      );
    }

    // Refresh details from the server to guarantee perfect state sync
    unawaited(refreshEventDetails());
  }

  void _handleSocketException(dynamic payload) {
    debugPrint('📡 [MusicVoteCubit] ← exception: $payload');

    if (isClosed) return;

    var errorMessage = 'Something went wrong on our end. Please try again.';

    if (payload is Map<String, dynamic>) {
      final msg = payload['message'];
      if (msg is String && msg.isNotEmpty) {
        errorMessage = msg;
      } else if (msg is List && msg.isNotEmpty) {
        errorMessage = msg.first.toString();
      } else if (payload['error'] is String) {
        errorMessage = payload['error'] as String;
      }
    } else if (payload is String && payload.isNotEmpty) {
      errorMessage = payload;
    }

    // Clear pending votes — since the server rejected the action,
    // and the UI was never optimistically updated, no rollback is needed.
    _pendingVotes.clear();

    // Map common technical errors to user-friendly ones
    if (errorMessage.contains('Internal Server Error') ||
        errorMessage.contains('500')) {
      errorMessage = 'Something went wrong on our end. Please try again.';
    }

    final isJoinError =
        errorMessage.contains('another device') ||
        errorMessage.contains('must use host_join') ||
        errorMessage.contains('already ended');

    emit(
      state.copyWith(
        isLoading: false,
        error: errorMessage,
        isStartingEvent: false,
        isEndingEvent: false,
        isJoinFailed: isJoinError || state.isJoinFailed,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Playback controls (host-only)
  // ---------------------------------------------------------------------------

  /// Emits `playback:play` for the current event.
  ///
  /// Allowed for the host AND any user the host has delegated to via
  /// the delegation flow (gated by `EventDetailModel.isDelegated`).
  void play() {
    if (!_canControlPlayback) return;
    final eventId = _activeEventId ?? state.event?.id;
    if (eventId == null || eventId.isEmpty) return;
    if (!_socketClient.isConnected) return;

    debugPrint('🚀 [MusicVoteCubit] Emitting: playbackPlay for $eventId');
    _socketClient.emit(SocketEvent.playbackPlay.value, <String, dynamic>{
      'eventId': eventId,
    });
  }

  /// Emits `playback:pause` for the current event.
  ///
  /// Allowed for the host AND any delegated user.
  void pause() {
    if (!_canControlPlayback) return;
    final eventId = _activeEventId ?? state.event?.id;
    if (eventId == null || eventId.isEmpty) return;
    if (!_socketClient.isConnected) return;

    debugPrint('🚀 [MusicVoteCubit] Emitting: playbackPause for $eventId');
    _socketClient.emit(SocketEvent.playbackPause.value, <String, dynamic>{
      'eventId': eventId,
    });
  }

  /// Emits `playback:next` for the current event.
  ///
  /// Allowed for the host AND any delegated user. The current `trackId`
  /// is forwarded as a staleness guard so the backend can ignore
  /// concurrent skips from a stale client view.
  void next() {
    if (!_canControlPlayback) return;
    final eventId = _activeEventId ?? state.event?.id;
    if (eventId == null || eventId.isEmpty) return;
    if (!_socketClient.isConnected) return;

    final currentTrackId = state.currentTrack?.id;
    _isWaitingForNextPlay = true;
    if (!_isHost) {
      setAudioLoading(isLoading: true);
    }

    debugPrint('🚀 [MusicVoteCubit] Emitting: playbackNext for $eventId');
    _socketClient.emit(SocketEvent.playbackNext.value, <String, dynamic>{
      'eventId': eventId,
      if (currentTrackId != null && currentTrackId.isNotEmpty)
        'trackId': currentTrackId,
    });
  }

  /// Consumes the flag indicating if the client should automatically emit
  /// `play` after the next track is fully loaded.
  bool consumeWaitingForNextPlay() {
    if (_isWaitingForNextPlay) {
      _isWaitingForNextPlay = false;
      return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Auto-advance (host-only)
  // ---------------------------------------------------------------------------

  /// (Re)schedules an auto-advance based on the current playback snapshot.
  /// Only the host arms the timer to avoid every client emitting `next`.
  void _schedulePlaybackAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = null;

    // Auto-advance is owned by the host to avoid every client emitting
    // `next` at the end of a track. Delegated users explicitly tap the
    // skip button if they want to advance early.
    if (!_isHost) return;
    if (state.playbackStatus != 'PLAYING') return;

    final track = state.currentTrack;
    if (track == null || track.durationMs <= 0) return;

    final int position;
    if (track.pausedPlaybackPositionMs != null) {
      position = track.pausedPlaybackPositionMs!;
    } else if (track.currentTrackStartedAt != null) {
      position = DateTime.now()
          .difference(track.currentTrackStartedAt!)
          .inMilliseconds;
    } else {
      position = 0;
    }
    final remainingMs = track.durationMs - position;
    if (remainingMs <= 0) {
      next();
      return;
    }

    final scheduledTrackId = track.id;
    _autoAdvanceTimer = Timer(Duration(milliseconds: remainingMs), () {
      // Re-check that the snapshot is still the same before skipping.
      if (isClosed) return;
      if (state.currentTrack?.id != scheduledTrackId) return;
      if (state.playbackStatus != 'PLAYING') return;
      next();
    });
  }

  @override
  Future<void> close() async {
    final eventId = _activeEventId ?? state.event?.id;
    debugPrint('👋 [MusicVoteCubit] Closing with eventId: $eventId');
    _autoAdvanceTimer?.cancel();
    await _socketConnectedSub?.cancel();
    await _socketDisconnectedSub?.cancel();
    await _delegationAcceptedSub?.cancel();
    await _delegationRemovedSub?.cancel();
    if (eventId != null && eventId.isNotEmpty) {
      leaveEvent(eventId);
    }
    _detachSocketListeners();
    return super.close();
  }
}
