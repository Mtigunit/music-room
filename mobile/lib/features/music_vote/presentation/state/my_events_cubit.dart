import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/features/events/data/datasources/event_remote_datasource.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

abstract class MyEventsState {}

class MyEventsInitial extends MyEventsState {}

class MyEventsLoading extends MyEventsState {}

class MyEventsSuccess extends MyEventsState {
  MyEventsSuccess({
    required this.invitedEvents,
    required this.hostedEvents,
  });

  final List<MyEventItemModel> invitedEvents;
  final List<MyEventItemModel> hostedEvents;
}

class MyEventsError extends MyEventsState {
  MyEventsError(this.message);

  final String message;
}

// ---------------------------------------------------------------------------
// Cubit
// ---------------------------------------------------------------------------

/// Manages the state for the "My Events" dashboard tabs.
///
/// Follows the same Clean Architecture pattern as `CreateEventCubit`:
/// the cubit depends on [IEventRemoteDataSource] and emits typed states.
class MyEventsCubit extends Cubit<MyEventsState> {
  MyEventsCubit({required IEventRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource,
      super(MyEventsInitial());

  final IEventRemoteDataSource _remoteDataSource;

  /// Concurrently fetches both the invited and hosted event lists then
  /// emits [MyEventsSuccess] (or [MyEventsError] on failure).
  Future<void> fetchEvents() async {
    emit(MyEventsLoading());
    await _doFetch();
  }

  /// Silently fetches both the invited and hosted event lists in the background
  /// without emitting [MyEventsLoading]. Replaces the old lists upon success.
  Future<void> refreshEvents() async {
    await _doFetch();
  }

  Future<void> _doFetch() async {
    try {
      final results = await Future.wait([
        _remoteDataSource.fetchInvitedEvents(),
        _remoteDataSource.fetchHostedEvents(),
      ]);

      if (isClosed) return;

      emit(
        MyEventsSuccess(
          invitedEvents: results[0],
          hostedEvents: results[1],
        ),
      );
    } on DioException catch (e) {
      if (isClosed) return;
      if (state is! MyEventsSuccess) {
        emit(MyEventsError(_extractDioMessage(e)));
      }
    } on Object {
      if (isClosed) return;
      if (state is! MyEventsSuccess) {
        emit(MyEventsError('Unable to load events right now.'));
      }
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

    return 'Unable to load events right now.';
  }
}
