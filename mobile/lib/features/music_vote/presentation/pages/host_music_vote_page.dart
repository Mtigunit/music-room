import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/music_vote/presentation/state/music_vote_cubit.dart';
import 'package:music_room/features/music_vote/presentation/widgets/event_ended_overlay.dart';
import 'package:music_room/features/music_vote/presentation/widgets/music_vote_view.dart';
import 'package:music_room/routes/route_names.dart';

/// Entry-point page for the "Live Event / Music Track Vote" feature.
///
/// Provides [MusicVoteCubit] and triggers `loadRoom` immediately.
/// This page is the tab-level widget mounted inside the app scaffold.
class HostMusicVotePage extends StatelessWidget {
  const HostMusicVotePage({
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
          socketClient: InjectionContainer().socketClient,
          tokenStorageService: InjectionContainer().tokenStorageService,
        );
        final id = eventId;
        if (id != null && id.isNotEmpty) {
          unawaited(cubit.loadRoom(id));
        }
        return cubit;
      },
      child: BlocListener<MusicVoteCubit, MusicVoteState>(
        listenWhen: (prev, curr) =>
            prev.event?.status != 'ENDED' && curr.event?.status == 'ENDED',
        listener: (context, state) {
          unawaited(
            showGeneralDialog(
              context: context,
              barrierColor: Colors.black.withValues(alpha: 0.8),
              pageBuilder: (context, animation, secondaryAnimation) =>
                  EventEndedOverlay(
                    onFinished: () {
                      if (context.mounted) {
                        unawaited(
                          Navigator.of(context).pushReplacementNamed(
                            RouteNames.preEvent,
                            arguments: eventId,
                          ),
                        );
                      }
                    },
                  ),
            ),
          );
        },
        child: MusicVoteView(
          eventId: eventId,
          isHost: true,
        ),
      ),
    );
  }
}
