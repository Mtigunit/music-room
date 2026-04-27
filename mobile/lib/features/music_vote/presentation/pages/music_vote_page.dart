import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/music_vote/presentation/state/music_vote_cubit.dart';
import 'package:music_room/features/music_vote/presentation/widgets/music_vote_view.dart';

/// Entry-point page for the "Live Event / Music Track Vote" feature.
///
/// Provides [MusicVoteCubit] and triggers `loadRoom` immediately.
/// This page is the tab-level widget mounted inside the app scaffold.
class MusicVotePage extends StatelessWidget {
  const MusicVotePage({
    super.key,
    this.eventId,
  });

  final String? eventId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = MusicVoteCubit(
          remoteDataSource: InjectionContainer().musicVoteRemoteDataSource,
        );
        final id = eventId;
        if (id != null && id.isNotEmpty) {
          unawaited(cubit.loadRoom(id));
        }
        return cubit;
      },
      child: MusicVoteView(eventId: eventId),
    );
  }
}
