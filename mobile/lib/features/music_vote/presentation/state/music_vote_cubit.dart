import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/realtime/socket_client.dart';
import 'package:music_room/core/realtime/socket_events.dart';
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
    this.error,
    this.event,
    this.tracks = const [],
    this.listenerCount,
    this.hostConnectionStatus,
  });

  final bool isLoading;
  final bool isAddingTrack;
  final bool isStartingEvent;
  final bool isEndingEvent;
  final String? error;
  final EventDetailModel? event;
  final List<EventTrackModel> tracks;
  final int? listenerCount;
  final HostConnectionStatus? hostConnectionStatus;

  MusicVoteState copyWith({
    bool? isLoading,
    bool? isAddingTrack,
    bool? isStartingEvent,
    bool? isEndingEvent,
    String? error,
    EventDetailModel? event,
    List<EventTrackModel>? tracks,
    int? listenerCount,
    HostConnectionStatus? hostConnectionStatus,
    bool clearError = false,
  }) {
    return MusicVoteState(
      isLoading: isLoading ?? this.isLoading,
      isAddingTrack: isAddingTrack ?? this.isAddingTrack,
      isStartingEvent: isStartingEvent ?? this.isStartingEvent,
      isEndingEvent: isEndingEvent ?? this.isEndingEvent,
      error: clearError ? null : (error ?? this.error),
      event: event ?? this.event,
      tracks: tracks ?? this.tracks,
      listenerCount: listenerCount ?? this.listenerCount,
      hostConnectionStatus: hostConnectionStatus ?? this.hostConnectionStatus,
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
    String? userId,
  }) : _repository = repository,
       _socketClient = socketClient,
       _currentUserId = userId,
       super(const MusicVoteState());

  final MusicVoteRepository _repository;
  final SocketClient _socketClient;

  String? _activeEventId;
  bool _socketListenersAttached = false;
  bool _hasJoinedLiveRoom = false;

  /// Tracks in-flight vote attempts: trackId → intended voteType ('up'|'none').
  /// The UI is NOT updated until the server confirms via [track:vote_updated].
  final Map<String, String> _pendingVotes = {};

  final String? _currentUserId;

  /// Loads the event details and queued tracks concurrently.
  Future<void> loadRoom(String eventId) async {
    _activeEventId = eventId;
    _hasJoinedLiveRoom = false;
    emit(state.copyWith(isLoading: true, clearError: true));
    await _ensureSocketConnected();

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
          isLoading: false,
          event: event,
          tracks: tracks,
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
    await _ensureSocketConnected();

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
  Future<void> endEvent(String eventId) async {
    if (state.isEndingEvent) return;
    emit(state.copyWith(isEndingEvent: true, clearError: true));

    _activeEventId = eventId;
    await _ensureSocketConnected();

    if (!_socketClient.isConnected) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isEndingEvent: false,
          error: 'Unable to connect to live updates.',
        ),
      );
      return;
    }

    try {
      debugPrint(
        '🚀 [MusicVoteCubit] Emitting: eventEnd for eventId: $eventId',
      );
      _socketClient.emit(SocketEvent.eventEnd.value, <String, dynamic>{
        'eventId': eventId,
      });
    } on Object {
      if (isClosed) return;
      emit(
        state.copyWith(
          isEndingEvent: false,
          error: 'Unable to end event.',
        ),
      );
    }
  }

  /// Manually leave the event room.
  void leaveEvent(String eventId) {
    if (eventId.isEmpty || !_socketClient.isConnected) return;

    final hostId = state.event?.hostId;
    final isHost =
        hostId != null && hostId.isNotEmpty && hostId == _currentUserId;

    final eventName = isHost
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

  Future<void> _ensureSocketConnected() async {
    _attachSocketListeners();
    await _socketClient.reconnectWithAuth();
  }

  void _attachSocketListeners() {
    _detachSocketListeners();
    _socketClient
      ..on(SocketEvent.connected.value, (_) {
        unawaited(_joinEventRoom());
      })
      ..on(SocketEvent.eventStarted.value, _handleEventStarted)
      ..on(SocketEvent.eventEnded.value, _handleEventEnded)
      ..on(SocketEvent.eventStatus.value, _handleEventStatus)
      ..on(SocketEvent.eventCount.value, _handleEventCount)
      ..on(SocketEvent.hostSoftDisconnect.value, _handleHostSoftDisconnect)
      ..on(SocketEvent.hostReconnected.value, _handleHostReconnected)
      ..on(SocketEvent.trackAdded.value, _handleTrackAdded)
      ..on(SocketEvent.trackRemoved.value, _handleTrackRemoved)
      ..on(SocketEvent.trackVoteUpdated.value, _handleTrackVoteUpdated)
      ..on(SocketEvent.exception.value, _handleSocketException);
    _socketListenersAttached = true;
  }

  void _detachSocketListeners() {
    if (!_socketListenersAttached) return;
    _socketClient
      ..off(SocketEvent.connected.value)
      ..off(SocketEvent.eventStarted.value)
      ..off(SocketEvent.eventEnded.value)
      ..off(SocketEvent.eventStatus.value)
      ..off(SocketEvent.eventCount.value)
      ..off(SocketEvent.hostSoftDisconnect.value)
      ..off(SocketEvent.hostReconnected.value)
      ..off(SocketEvent.trackAdded.value)
      ..off(SocketEvent.trackRemoved.value)
      ..off(SocketEvent.trackVoteUpdated.value)
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
        event: updated,
        isStartingEvent:
            status != 'LIVE' && status != 'ENDED' && state.isStartingEvent,
        isEndingEvent: status != 'ENDED' && state.isEndingEvent,
        clearError: true,
      ),
    );
  }

  void _sortTracks(List<EventTrackModel> tracks) {
    tracks.sort((a, b) {
      final voteDiff = b.voteScore.compareTo(a.voteScore);
      if (voteDiff != 0) return voteDiff;
      // Tie breaker by id length or lexicographical
      // (a fallback since addedAt doesn't exist on this model).
      return a.id.compareTo(b.id);
    });
  }

  Future<void> _joinEventRoom() async {
    if (_hasJoinedLiveRoom) return;
    final event = state.event;
    if (event == null) return;
    if (event.status != 'LIVE') return;
    final eventId = _activeEventId ?? event.id;
    if (eventId.isEmpty) return;
    if (!_socketClient.isConnected) return;

    final hostId = event.hostId;
    final isHost = hostId.isNotEmpty && hostId == _currentUserId;
    final eventName = isHost
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

  void clearError() {
    if (!isClosed) {
      emit(state.copyWith(clearError: true));
    }
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

    emit(state.copyWith(error: errorMessage));
  }

  @override
  Future<void> close() {
    final eventId = _activeEventId ?? state.event?.id;
    debugPrint('👋 [MusicVoteCubit] Closing with eventId: $eventId');
    if (eventId != null && eventId.isNotEmpty) {
      leaveEvent(eventId);
    }
    _detachSocketListeners();
    return super.close();
  }
}
