import 'package:flutter/material.dart';
import 'package:music_room/features/music_vote/data/models/event_detail_model.dart';
import 'package:music_room/features/music_vote/presentation/pages/host_event_info_view.dart';
import 'package:music_room/features/music_vote/presentation/widgets/invite_users_button.dart';

class EventActionsRow extends StatelessWidget {
  const EventActionsRow({
    required this.event,
    required this.colorScheme,
    super.key,
  });

  final EventDetailModel event;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: AddTracksButton(
            eventId: event.id,
            colorScheme: colorScheme,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: InviteUsersButton(
            event: event,
            colorScheme: colorScheme,
          ),
        ),
      ],
    );
  }
}
