import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/features/music_vote/data/datasources/music_vote_remote_datasource.dart';
import 'package:music_room/features/music_vote/data/models/event_detail_model.dart';
import 'package:music_room/features/music_vote/data/models/event_track_model.dart';

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
  });

  final bool isLoading;
  final bool isAddingTrack;
  final bool isStartingEvent;
  final bool isEndingEvent;
  final String? error;
  final EventDetailModel? event;
  final List<EventTrackModel> tracks;

  MusicVoteState copyWith({
    bool? isLoading,
    bool? isAddingTrack,
    bool? isStartingEvent,
    bool? isEndingEvent,
    String? error,
    EventDetailModel? event,
    List<EventTrackModel>? tracks,
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
    );
  }
}

// ---------------------------------------------------------------------------
// Cubit
// ---------------------------------------------------------------------------

class MusicVoteCubit extends Cubit<MusicVoteState> {
  MusicVoteCubit({
    required IMusicVoteRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource,
       super(const MusicVoteState());

  final IMusicVoteRemoteDataSource _remoteDataSource;

  /// Loads the event details and queued tracks concurrently.
  Future<void> loadRoom(String eventId) async {
    emit(state.copyWith(isLoading: true, clearError: true));

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
  /// Calls POST /events/{id}/start and updates the local state
  /// with the returned event so the UI switches to the LIVE view.
  Future<void> startEvent(String eventId) async {
    emit(state.copyWith(isStartingEvent: true, clearError: true));

    try {
      final updatedEvent = await _remoteDataSource.startEvent(eventId);

      if (isClosed) return;

      emit(
        state.copyWith(
          isStartingEvent: false,
          event: updatedEvent,
        ),
      );
    } on DioException catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isStartingEvent: false,
          error: _extractDioMessage(e),
        ),
      );
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
  /// Calls POST /events/{id}/end and updates the local state
  /// with the returned event so the UI reflects the ended state.
  Future<void> endEvent(String eventId) async {
    emit(state.copyWith(isEndingEvent: true, clearError: true));

    try {
      final updatedEvent = await _remoteDataSource.endEvent(eventId);

      if (isClosed) return;

      emit(
        state.copyWith(
          isEndingEvent: false,
          event: updatedEvent,
        ),
      );
    } on DioException catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isEndingEvent: false,
          error: _extractDioMessage(e),
        ),
      );
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
}
