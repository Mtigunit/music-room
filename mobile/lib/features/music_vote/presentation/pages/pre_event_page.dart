import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/music_vote/presentation/state/music_vote_cubit.dart';
import 'package:music_room/features/music_vote/presentation/widgets/pre_event_info_view.dart';
import 'package:music_room/features/music_vote/presentation/widgets/skeletons/pre_event_skeleton.dart';
import 'package:music_room/routes/route_names.dart';

class PreEventPage extends StatelessWidget {
  const PreEventPage({
    required this.eventId,
    super.key,
  });

  final String eventId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = MusicVoteCubit(
          remoteDataSource: InjectionContainer().musicVoteRemoteDataSource,
          socketClient: InjectionContainer().socketClient,
          tokenStorageService: InjectionContainer().tokenStorageService,
        );
        unawaited(cubit.loadRoom(eventId));
        return cubit;
      },
      child: BlocConsumer<MusicVoteCubit, MusicVoteState>(
        listenWhen: (prev, curr) =>
            prev.event?.status != 'LIVE' && curr.event?.status == 'LIVE',
        listener: (context, state) {
          unawaited(
            Navigator.of(context).pushReplacementNamed(
              RouteNames.musicVote,
              arguments: eventId,
            ),
          );
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

          return PreEventInfoView(
            event: state.event!,
            tracks: state.tracks,
          );
        },
      ),
    );
  }
}
