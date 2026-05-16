import 'package:music_room/features/music_vote/data/models/event_detail_model.dart';
import 'package:music_room/features/music_vote/data/models/event_track_model.dart';

abstract class MusicVoteRepository {
  Future<EventDetailModel> getEventDetails(String eventId);
  Future<List<EventTrackModel>> getEventTracks(
    String eventId, {
    int page,
    int limit,
  });
  Future<EventTrackModel> addTrack(String eventId, String providerTrackId);
  Future<void> removeTrack(String eventId, String providerTrackId);
  Future<void> inviteUserToEvent(String eventId, String userId);
}
