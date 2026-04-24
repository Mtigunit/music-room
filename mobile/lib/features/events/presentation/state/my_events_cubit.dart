import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/features/events/data/models/my_event_item.dart';
import 'package:music_room/features/events/data/models/my_events_mock_data.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class MyEventsState {
  const MyEventsState({
    this.isLoading = false,
    this.attendingEvents = const [],
    this.hostingEvents = const [],
    this.error,
  });

  final bool isLoading;
  final List<MyEventItem> attendingEvents;
  final List<MyEventItem> hostingEvents;
  final String? error;

  MyEventsState copyWith({
    bool? isLoading,
    List<MyEventItem>? attendingEvents,
    List<MyEventItem>? hostingEvents,
    String? error,
    bool clearError = false,
  }) {
    return MyEventsState(
      isLoading: isLoading ?? this.isLoading,
      attendingEvents: attendingEvents ?? this.attendingEvents,
      hostingEvents: hostingEvents ?? this.hostingEvents,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ---------------------------------------------------------------------------
// Cubit
// ---------------------------------------------------------------------------

/// Manages the state for the "My Events" dashboard tabs.
///
/// Currently loads mock data. Replace the body of [loadEvents] with
/// real API calls when the backend endpoints are ready.
class MyEventsCubit extends Cubit<MyEventsState> {
  MyEventsCubit() : super(const MyEventsState());

  /// Simulates loading the user's attending and hosting events.
  Future<void> loadEvents() async {
    emit(state.copyWith(isLoading: true, clearError: true));

    // Simulate a short network delay for realistic UX.
    await Future<void>.delayed(const Duration(milliseconds: 400));

    if (isClosed) return;

    emit(
      state.copyWith(
        isLoading: false,
        attendingEvents: MyEventsMockData.attending,
        hostingEvents: MyEventsMockData.hosting,
      ),
    );
  }
}
