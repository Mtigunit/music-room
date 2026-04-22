import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/features/events/data/datasources/track_remote_datasource.dart';
import 'package:music_room/features/events/data/models/track_model.dart';

abstract class TrackSearchState {}

class TrackSearchInitial extends TrackSearchState {}

class TrackSearchLoading extends TrackSearchState {}

class TrackSearchLoaded extends TrackSearchState {
  TrackSearchLoaded(this.tracks);
  final List<TrackModel> tracks;
}

class TrackSearchError extends TrackSearchState {
  TrackSearchError(this.message);
  final String message;
}

class TrackSearchCubit extends Cubit<TrackSearchState> {
  TrackSearchCubit({required ITrackRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource,
      super(TrackSearchInitial());
  final ITrackRemoteDataSource _remoteDataSource;
  Timer? _debounceTimer;

  void searchTracks(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    if (query.trim().isEmpty) {
      emit(TrackSearchInitial());
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (isClosed) return;
      emit(TrackSearchLoading());
      try {
        final results = await _remoteDataSource.searchTracks(query);
        if (isClosed) return;
        emit(TrackSearchLoaded(results));
      } on DioException catch (e) {
        if (isClosed) return;
        emit(TrackSearchError(e.message ?? 'Network error occurred'));
      } on Object catch (e) {
        if (isClosed) return;
        emit(TrackSearchError('Server error: $e'));
      }
    });
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}
