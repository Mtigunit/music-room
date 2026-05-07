import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/auth/presentation/state/auth_state.dart';
import 'package:music_room/features/music_vote/presentation/pages/guest_music_vote_page.dart';
import 'package:music_room/features/music_vote/presentation/pages/host_music_vote_page.dart';
import 'package:music_room/features/music_vote/presentation/state/music_vote_cubit.dart';
import 'package:music_room/features/music_vote/presentation/widgets/guest_event_info_view.dart';
import 'package:music_room/features/music_vote/presentation/widgets/host_event_info_view.dart';
import 'package:music_room/features/music_vote/presentation/widgets/skeletons/pre_event_skeleton.dart';

class PreEventPage extends StatelessWidget {
  const PreEventPage({
    required this.eventId,
    super.key,
  });

  final String eventId;

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
          userId: userId,
        );
        unawaited(cubit.loadRoom(eventId));
        return cubit;
      },
      child: BlocConsumer<MusicVoteCubit, MusicVoteState>(
        listenWhen: (prev, curr) =>
            prev.event?.status != 'LIVE' && curr.event?.status == 'LIVE',
        listener: (context, state) {
          final isHost = state.event?.hostId == userId;
          if (isHost) {
            unawaited(
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => HostMusicVotePage(eventId: eventId),
                ),
              ),
            );
          } else {
            unawaited(
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => GuestMusicVotePage(eventId: eventId),
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.isLoading || state.event == null) {
            if (state.error != null) {
              return Scaffold(
                appBar: AppBar(title: const Text('Error')),
                body: Center(child: Text(state.error!)),
              );
            }
            return const PreEventSkeleton();
          }

          final event = state.event!;
          final isHost = userId == event.hostId;

          if (isHost) {
            return HostEventInfoView(event: event, tracks: state.tracks);
          } else {
            return GuestEventInfoView(event: event, tracks: state.tracks);
          }
        },
      ),
    );
  }
}
