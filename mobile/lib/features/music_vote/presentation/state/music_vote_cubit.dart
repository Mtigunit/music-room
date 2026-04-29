import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/realtime/socket_client.dart';
import 'package:music_room/core/realtime/socket_events.dart';
import 'package:music_room/core/services/token_storage_service.dart';
import 'package:music_room/features/music_vote/data/datasources/music_vote_remote_datasource.dart';
import 'package:music_room/features/music_vote/data/models/event_detail_model.dart';
import 'package:music_room/features/music_vote/data/models/event_track_model.dart';

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
    required IMusicVoteRemoteDataSource remoteDataSource,
    required SocketClient socketClient,
    required TokenStorageService tokenStorageService,
  }) : _remoteDataSource = remoteDataSource,
       _socketClient = socketClient,
       _tokenStorageService = tokenStorageService,
       super(const MusicVoteState());

  final IMusicVoteRemoteDataSource _remoteDataSource;
  final SocketClient _socketClient;
  final TokenStorageService _tokenStorageService;

  String? _activeEventId;
  bool _socketListenersAttached = false;

  String? _currentUserId;
  bool _userIdLoaded = false;

  /// Loads the event details and queued tracks concurrently.
  Future<void> loadRoom(String eventId) async {
    _activeEventId = eventId;
    emit(state.copyWith(isLoading: true, clearError: true));
    await _ensureSocketConnected();

    try {
      final results = await Future.wait([
        _remoteDataSource.getEventDetails(eventId),
        _remoteDataSource.getEventTracks(eventId),
      ]);

      if (isClosed) return;

      final event = results[0] as EventDetailModel;
      final tracks = results[1] as List<EventTrackModel>;

      emit(
        state.copyWith(
          isLoading: false,
          event: event,
          tracks: tracks,
        ),
      );

      await _loadCurrentUserId();
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
      await _remoteDataSource.addTrackToEvent(eventId, providerTrackId);

      if (isClosed) return;

      // Re-fetch to get the server's canonical ordering.
      final tracks = await _remoteDataSource.getEventTracks(eventId);

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
      ..on(SocketEvent.hostReconnected.value, _handleHostReconnected);
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
      ..off(SocketEvent.hostReconnected.value);
    _socketListenersAttached = false;
  }

  void _handleEventStarted(dynamic payload) {
    if (!_isRelevantEventPayload(payload)) return;
    final status = _extractStatus(payload) ?? 'LIVE';
    final startDate = _extractStartDate(payload);
    _applyEventStatus(status, startDate: startDate);
  }

  void _handleEventEnded(dynamic payload) {
    if (!_isRelevantEventPayload(payload)) return;

    final eventId = _activeEventId ?? state.event?.id;
    if (eventId != null && eventId.isNotEmpty && _socketClient.isConnected) {
      _socketClient.emit(SocketEvent.eventLeave.value, <String, dynamic>{
        'eventId': eventId,
      });
    }

    _applyEventStatus('ENDED');
  }

  void _handleEventStatus(dynamic payload) {
    if (!_isRelevantEventPayload(payload)) return;
    final status = _extractStatus(payload);
    if (status == null) return;
    final startDate = _extractStartDate(payload);
    _applyEventStatus(status, startDate: startDate);
  }

  void _handleEventCount(dynamic payload) {
    if (!_isRelevantEventPayload(payload)) return;
    if (payload is Map<String, dynamic>) {
      final count = payload['count'];
      if (count is int) {
        emit(state.copyWith(listenerCount: count));
      }
    }
  }

  void _handleHostSoftDisconnect(dynamic payload) {
    if (!_isRelevantEventPayload(payload)) return;
    emit(
      state.copyWith(hostConnectionStatus: HostConnectionStatus.disconnected),
    );
  }

  void _handleHostReconnected(dynamic payload) {
    if (!_isRelevantEventPayload(payload)) return;
    emit(
      state.copyWith(hostConnectionStatus: HostConnectionStatus.reconnected),
    );
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

    final updated = EventDetailModel(
      id: current.id,
      name: current.name,
      description: current.description,
      coverImage: current.coverImage,
      status: status,
      visibility: current.visibility,
      invitingOnly: current.invitingOnly,
      tags: current.tags,
      hostId: current.hostId,
      locationLat: current.locationLat,
      locationLng: current.locationLng,
      playbackStatus: current.playbackStatus,
      currentTrackId: current.currentTrackId,
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

  Future<void> _joinEventRoom() async {
    final event = state.event;
    if (event == null) return;
    final eventId = _activeEventId ?? event.id;
    if (eventId.isEmpty) return;
    if (!_socketClient.isConnected) return;

    await _loadCurrentUserId();
    final hostId = event.hostId;
    final isHost = hostId.isNotEmpty && hostId == _currentUserId;
    final eventName = isHost
        ? SocketEvent.eventHostJoin.value
        : SocketEvent.eventJoin.value;

    _socketClient.emit(eventName, <String, dynamic>{'eventId': eventId});
  }

  Future<void> _loadCurrentUserId() async {
    if (_userIdLoaded) return;
    _userIdLoaded = true;

    final userJson = await _tokenStorageService.getUserProfile();
    if (userJson != null && userJson.isNotEmpty) {
      try {
        final parsed = jsonDecode(userJson);
        if (parsed is Map<String, dynamic>) {
          final id = parsed['id'] ?? parsed['userId'];
          if (id is String && id.isNotEmpty) {
            _currentUserId = id;
            return;
          }
        }
      } on Object {
        _currentUserId = null;
      }
    }

    final token = await _tokenStorageService.getToken();
    _currentUserId = _extractUserIdFromJwt(token);
  }

  String? _extractUserIdFromJwt(String? token) {
    if (token == null || token.isEmpty) return null;
    final parts = token.split('.');
    if (parts.length < 2) return null;

    try {
      final normalized = base64Url.normalize(parts[1]);
      final payloadJson = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(payloadJson);
      if (payload is! Map<String, dynamic>) return null;

      final candidates = <dynamic>[
        payload['userId'],
        payload['id'],
        payload['sub'],
      ];

      for (final candidate in candidates) {
        if (candidate is String && candidate.isNotEmpty) {
          return candidate;
        }
      }
    } on Object {
      return null;
    }

    return null;
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

  @override
  Future<void> close() {
    final event = state.event;
    final eventId = _activeEventId ?? event?.id;

    if (eventId != null && eventId.isNotEmpty && _socketClient.isConnected) {
      final hostId = event?.hostId;
      final isHost =
          hostId != null && hostId.isNotEmpty && hostId == _currentUserId;
      final leaveEvent = isHost
          ? SocketEvent.eventHostLeave.value
          : SocketEvent.eventLeave.value;

      _socketClient.emit(leaveEvent, <String, dynamic>{'eventId': eventId});
    }

    _detachSocketListeners();
    return super.close();
  }
}
