import 'package:music_room/features/events/data/datasources/event_remote_datasource.dart';

abstract class HomeEventsState {}

class HomeEventsInitial extends HomeEventsState {}

class HomeEventsLoading extends HomeEventsState {}

class HomeEventsSuccess extends HomeEventsState {
  HomeEventsSuccess({
    required this.exploreEvents,
    required this.friendsEvents,
    required this.explorePage,
    required this.friendsPage,
    required this.hasMoreExplore,
    required this.hasMoreFriends,
  });

  final List<MyEventItemModel> exploreEvents;
  final List<MyEventItemModel> friendsEvents;
  final int explorePage;
  final int friendsPage;
  final bool hasMoreExplore;
  final bool hasMoreFriends;

  HomeEventsSuccess copyWith({
    List<MyEventItemModel>? exploreEvents,
    List<MyEventItemModel>? friendsEvents,
    int? explorePage,
    int? friendsPage,
    bool? hasMoreExplore,
    bool? hasMoreFriends,
  }) {
    return HomeEventsSuccess(
      exploreEvents: exploreEvents ?? this.exploreEvents,
      friendsEvents: friendsEvents ?? this.friendsEvents,
      explorePage: explorePage ?? this.explorePage,
      friendsPage: friendsPage ?? this.friendsPage,
      hasMoreExplore: hasMoreExplore ?? this.hasMoreExplore,
      hasMoreFriends: hasMoreFriends ?? this.hasMoreFriends,
    );
  }
}

class HomeEventsError extends HomeEventsState {
  HomeEventsError(this.message);

  final String message;
}
