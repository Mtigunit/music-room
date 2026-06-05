import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/auth/presentation/state/auth_state.dart';
import 'package:music_room/features/music_vote/presentation/state/music_vote_cubit.dart';
import 'package:music_room/features/music_vote/presentation/widgets/event_ended_overlay.dart';
import 'package:music_room/features/music_vote/presentation/widgets/music_vote_view.dart';

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

  String? _currentUserId(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) return authState.user.id;
    if (authState is LoginSuccess) return authState.user.id;
    if (authState is RegisterSuccess) return authState.user.id;
    if (authState is GoogleLoginSuccess) return authState.user.id;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final userId = _currentUserId(context);

    return BlocProvider(
      create: (_) {
        final cubit = MusicVoteCubit(
          repository: InjectionContainer().musicVoteRepository,
          socketClient: InjectionContainer().socketClient,
          delegationGateway: InjectionContainer().delegationGateway,
          userId: userId,
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
                        Navigator.of(context, rootNavigator: true).pop();
                        if (context.mounted) {
                          final currentEventId = eventId?.trim();
                          if (currentEventId == null ||
                              currentEventId.isEmpty) {
                            return;
                          }

                          context.go('/events/$currentEventId');
                        }
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
