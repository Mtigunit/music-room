import 'package:music_room/features/music_vote/data/datasources/music_vote_remote_datasource.dart';
import 'package:music_room/features/music_vote/data/models/event_detail_model.dart';
import 'package:music_room/features/music_vote/data/models/event_track_model.dart';
import 'package:music_room/features/music_vote/domain/repositories/music_vote_repository.dart';

class MusicVoteRepositoryImpl implements MusicVoteRepository {
  MusicVoteRepositoryImpl({
    required IMusicVoteRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final IMusicVoteRemoteDataSource _remoteDataSource;

  @override
  Future<EventDetailModel> getEventDetails(String eventId) async {
    return _remoteDataSource.getEventDetails(eventId);
  }

  @override
  Future<List<EventTrackModel>> getEventTracks(
    String eventId, {
    int page = 1,
    int limit = 20,
  }) async {
    return _remoteDataSource.getEventTracks(eventId, page: page, limit: limit);
  }

  @override
  Future<EventTrackModel> addTrack(
    String eventId,
    String providerTrackId,
  ) async {
    return _remoteDataSource.addTrackToEvent(eventId, providerTrackId);
  }

  @override
  Future<void> removeTrack(String eventId, String providerTrackId) async {
    await _remoteDataSource.removeTrackFromEvent(eventId, providerTrackId);
  }

  @override
  Future<void> inviteUserToEvent(String eventId, String userId) async {
    await _remoteDataSource.inviteUserToEvent(eventId, userId);
  }
}
