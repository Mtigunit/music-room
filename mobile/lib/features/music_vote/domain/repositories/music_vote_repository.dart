import 'package:music_room/features/music_vote/data/datasources/music_vote_remote_datasource.dart'
    show EventInvitedUsersPage;
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

  /// Lists users invited to the event.
  Future<EventInvitedUsersPage> getInvitedUsers(
    String eventId, {
    int page,
    int limit,
  });

  /// Grants playback delegation to [delegateeId]. Returns the
  /// `delegationId` issued by the backend.
  Future<String> createDelegation(String eventId, String delegateeId);
}
