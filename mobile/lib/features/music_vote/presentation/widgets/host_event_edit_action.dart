import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/features/events/presentation/widgets/edit_event_sheet.dart';
import 'package:music_room/features/music_vote/data/models/event_detail_model.dart';
import 'package:music_room/features/music_vote/data/models/event_track_model.dart';
import 'package:music_room/features/music_vote/presentation/state/music_vote_cubit.dart';

class HostEventEditAction extends StatelessWidget {
  const HostEventEditAction({
    required this.event,
    required this.tracks,
    super.key,
  });

  final EventDetailModel event;
  final List<EventTrackModel> tracks;

  @override
  Widget build(BuildContext context) {
    if (event.status == 'ENDED') {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: SizedBox(
        width: 40,
        height: 40,
        child: IconButton(
          onPressed: () async {
            final didEdit = await showModalBottomSheet<bool>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => EditEventSheet(
                event: event,
                tracks: tracks,
              ),
            );

            if (didEdit == true && context.mounted) {
              unawaited(
                context.read<MusicVoteCubit>().loadRoom(event.id),
              );
            }
          },
          icon: const Icon(Icons.edit_rounded, size: 18),
          style: IconButton.styleFrom(
            foregroundColor: colorScheme.onSurface,
            backgroundColor: colorScheme.surface,
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}
