import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/features/search/data/datasources/search_remote_datasource.dart';
import 'package:music_room/features/search/data/models/search_filter_type.dart';
import 'package:music_room/features/search/data/models/search_result_models.dart';

enum SearchStatus { idle, loading, success, failure }

class SearchState {
  const SearchState({
    required this.query,
    required this.filter,
    required this.status,
    required this.results,
    this.errorMessage,
  });

  factory SearchState.initial({
    SearchFilterType filter = SearchFilterType.events,
    String query = '',
  }) {
    return SearchState(
      query: query,
      filter: filter,
      status: SearchStatus.idle,
      results: const <SearchResultModel>[],
    );
  }

  final String query;
  final SearchFilterType filter;
  final SearchStatus status;
  final List<SearchResultModel> results;
  final String? errorMessage;

  bool get hasQuery => query.trim().isNotEmpty;
  bool get isLoading => status == SearchStatus.loading;
  bool get hasError => status == SearchStatus.failure;
  bool get isEmpty => status == SearchStatus.success && results.isEmpty;

  SearchState copyWith({
    String? query,
    SearchFilterType? filter,
    SearchStatus? status,
    List<SearchResultModel>? results,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      filter: filter ?? this.filter,
      status: status ?? this.status,
      results: results ?? this.results,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class SearchCubit extends Cubit<SearchState> {
  SearchCubit({required ISearchRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource,
      super(SearchState.initial());

  final ISearchRemoteDataSource _remoteDataSource;
  Timer? _debounceTimer;
  int _requestId = 0;

  void hydrate({required String query, required SearchFilterType filter}) {
    emit(SearchState.initial(filter: filter, query: query));
    if (query.trim().isNotEmpty) {
      _scheduleSearch(query.trim(), filter: filter);
    }
  }

  void updateQuery(String query) {
    final trimmedQuery = query.trim();
    _debounceTimer?.cancel();
    _requestId++;

    if (trimmedQuery.isEmpty) {
      emit(
        state.copyWith(
          query: '',
          status: SearchStatus.idle,
          results: const <SearchResultModel>[],
          clearError: true,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        query: query,
        status: SearchStatus.idle,
        clearError: true,
      ),
    );
    _scheduleSearch(trimmedQuery, filter: state.filter);
  }

  void submitQuery(String query) {
    final trimmedQuery = query.trim();
    _debounceTimer?.cancel();
    _requestId++;

    if (trimmedQuery.isEmpty) {
      emit(
        state.copyWith(
          query: '',
          status: SearchStatus.idle,
          results: const <SearchResultModel>[],
          clearError: true,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        query: query,
        status: SearchStatus.loading,
        clearError: true,
      ),
    );
    _scheduleSearch(trimmedQuery, filter: state.filter, immediate: true);
  }

  void changeFilter(SearchFilterType filter) {
    if (state.filter == filter) {
      return;
    }

    _debounceTimer?.cancel();
    _requestId++;

    final nextState = state.copyWith(
      filter: filter,
      status: state.hasQuery ? SearchStatus.loading : SearchStatus.idle,
      clearError: true,
    );
    emit(nextState);

    if (nextState.hasQuery) {
      _scheduleSearch(nextState.query.trim(), filter: filter);
    }
  }

  void retry() {
    final trimmedQuery = state.query.trim();
    if (trimmedQuery.isEmpty) {
      return;
    }

    _debounceTimer?.cancel();
    _scheduleSearch(trimmedQuery, filter: state.filter, immediate: true);
  }

  void _scheduleSearch(
    String query, {
    required SearchFilterType filter,
    bool immediate = false,
  }) {
    _debounceTimer?.cancel();
    final currentRequestId = ++_requestId;

    void performSearch() {
      unawaited(_performSearch(query, filter, currentRequestId));
    }

    if (immediate) {
      performSearch();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 450), performSearch);
  }

  Future<void> _performSearch(
    String query,
    SearchFilterType filter,
    int requestId,
  ) async {
    if (query.trim().isEmpty) {
      return;
    }

    emit(
      state.copyWith(
        status: SearchStatus.loading,
        clearError: true,
      ),
    );

    try {
      final results = switch (filter) {
        SearchFilterType.tracks => await _remoteDataSource.searchTracks(query),
        SearchFilterType.users => await _remoteDataSource.searchUsers(query),
        SearchFilterType.events => await _remoteDataSource.searchEvents(query),
        SearchFilterType.playlists => await _remoteDataSource.searchPlaylists(
          query,
        ),
      };

      if (isClosed || requestId != _requestId) {
        return;
      }

      emit(
        state.copyWith(
          status: SearchStatus.success,
          results: results,
          clearError: true,
        ),
      );
    } on DioException catch (error) {
      if (isClosed || requestId != _requestId) {
        return;
      }

      emit(
        state.copyWith(
          status: SearchStatus.failure,
          results: const <SearchResultModel>[],
          errorMessage: _buildNetworkErrorMessage(error),
        ),
      );
    } on Object {
      if (isClosed || requestId != _requestId) {
        return;
      }

      emit(
        state.copyWith(
          status: SearchStatus.failure,
          results: const <SearchResultModel>[],
          errorMessage:
              'Something went wrong while searching. Please try again.',
        ),
      );
    }
  }

  String _buildNetworkErrorMessage(DioException error) {
    if (error.response?.statusCode == 400) {
      return 'Please enter a more specific search query.';
    }

    return 'Unable to fetch search results right now.';
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}
