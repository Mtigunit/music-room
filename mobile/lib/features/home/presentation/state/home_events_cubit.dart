import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/features/home/domain/repositories/home_repository.dart';
import 'package:music_room/features/home/presentation/state/home_events_state.dart';

class HomeEventsCubit extends Cubit<HomeEventsState> {
  HomeEventsCubit({required HomeRepository homeRepository})
    : _homeRepository = homeRepository,
      super(HomeEventsInitial());

  final HomeRepository _homeRepository;

  static const int _limit = 20;

  String? _currentTags;
  String? _currentStatus;
  String? _currentSearch;

  bool _isLoadingMoreExplore = false;
  bool _isLoadingMoreFriends = false;

  int _requestEpoch = 0;

  Future<void> fetchEvents({
    String? tags,
    String? status,
    String? search,
  }) async {
    _currentTags = tags ?? _currentTags;
    _currentStatus = status ?? _currentStatus;
    _currentSearch = search ?? _currentSearch;

    final epoch = ++_requestEpoch;
    emit(HomeEventsLoading());

    try {
      final results = await Future.wait([
        _homeRepository.fetchExploreEvents(
          tags: _currentTags,
          status: _currentStatus,
          search: _currentSearch,
        ),
        _homeRepository.fetchFriendsEvents(
          tags: _currentTags,
          status: _currentStatus,
          search: _currentSearch,
        ),
      ]);

      if (isClosed || epoch != _requestEpoch) return;

      final exploreEvents = results[0];
      final friendsEvents = results[1];

      emit(
        HomeEventsSuccess(
          exploreEvents: exploreEvents,
          friendsEvents: friendsEvents,
          explorePage: 1,
          friendsPage: 1,
          hasMoreExplore: exploreEvents.length == _limit,
          hasMoreFriends: friendsEvents.length == _limit,
        ),
      );
    } on DioException catch (e) {
      if (isClosed || epoch != _requestEpoch) return;
      emit(HomeEventsError(_extractDioMessage(e)));
    } on Object {
      if (isClosed || epoch != _requestEpoch) return;
      emit(HomeEventsError('Unable to load home events right now.'));
    }
  }

  Future<void> loadMoreExplore() async {
    if (_isLoadingMoreExplore) return;

    final currentState = state;
    if (currentState is! HomeEventsSuccess || !currentState.hasMoreExplore) {
      return;
    }

    final epoch = ++_requestEpoch;
    _isLoadingMoreExplore = true;
    final nextPage = currentState.explorePage + 1;

    try {
      final newEvents = await _homeRepository.fetchExploreEvents(
        page: nextPage,
        tags: _currentTags,
        status: _currentStatus,
        search: _currentSearch,
      );

      if (isClosed || epoch != _requestEpoch) return;

      emit(
        currentState.copyWith(
          exploreEvents: [...currentState.exploreEvents, ...newEvents],
          explorePage: nextPage,
          hasMoreExplore: newEvents.length == _limit,
        ),
      );
    } on Object {
      // Silently fail load more
    } finally {
      _isLoadingMoreExplore = false;
    }
  }

  Future<void> loadMoreFriends() async {
    if (_isLoadingMoreFriends) return;

    final currentState = state;
    if (currentState is! HomeEventsSuccess || !currentState.hasMoreFriends) {
      return;
    }

    final epoch = ++_requestEpoch;
    _isLoadingMoreFriends = true;
    final nextPage = currentState.friendsPage + 1;

    try {
      final newEvents = await _homeRepository.fetchFriendsEvents(
        page: nextPage,
        tags: _currentTags,
        status: _currentStatus,
        search: _currentSearch,
      );

      if (isClosed || epoch != _requestEpoch) return;

      emit(
        currentState.copyWith(
          friendsEvents: [...currentState.friendsEvents, ...newEvents],
          friendsPage: nextPage,
          hasMoreFriends: newEvents.length == _limit,
        ),
      );
    } on Object {
      // Silently fail load more
    } finally {
      _isLoadingMoreFriends = false;
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
