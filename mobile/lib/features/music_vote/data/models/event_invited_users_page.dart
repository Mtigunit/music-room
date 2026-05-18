import 'package:music_room/features/music_vote/data/models/event_invited_user_model.dart';

/// Page wrapper for [EventInvitedUserModel] representing a paginated segment
/// of guests invited to an event.
class EventInvitedUsersPage {
  const EventInvitedUsersPage({
    required this.users,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  final List<EventInvitedUserModel> users;
  final int total;
  final int page;
  final int limit;
  final int totalPages;
}
