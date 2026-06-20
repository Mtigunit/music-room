import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/widgets/dynamic_search_bottom_sheet.dart';
import 'package:music_room/core/widgets/track_search_list_tile.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/events/presentation/state/track_search_cubit.dart';
import 'package:music_room/features/music_vote/presentation/state/music_vote_cubit.dart';

class AddTracksButton extends StatelessWidget {
  const AddTracksButton({
    required this.eventId,
    required this.colorScheme,
    super.key,
  });
  final String eventId;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showAddTracksSheet(context),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Add Tracks',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddTracksSheet(BuildContext context) async {
    final musicVoteCubit = context.read<MusicVoteCubit>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BlocProvider(
        create: (_) => TrackSearchCubit(
          remoteDataSource: InjectionContainer().trackRemoteDataSource,
        ),
        child: _PreEventAddTrackSheet(
          eventId: eventId,
          musicVoteCubit: musicVoteCubit,
        ),
      ),
    );
  }
}

class _PreEventAddTrackSheet extends StatelessWidget {
  const _PreEventAddTrackSheet({
    required this.eventId,
    required this.musicVoteCubit,
  });
  final String eventId;
  final MusicVoteCubit musicVoteCubit;

  @override
  Widget build(BuildContext context) {
    return DynamicSearchBottomSheet(
      title: 'Add Tracks',
      subtitle: 'Build your event queue before going live',
      searchHintText: 'Search for songs, artists, or albums...',
      onSearchChanged: (query) =>
          context.read<TrackSearchCubit>().searchTracks(query),
      content: BlocBuilder<TrackSearchCubit, TrackSearchState>(
        builder: (context, state) {
          if (state is TrackSearchLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is TrackSearchLoaded) {
            return ListView.separated(
              itemCount: state.tracks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final track = state.tracks[index];
                return TrackSearchListTile(
                  track: track,
                  onAddTapped: (added) async =>
                      musicVoteCubit.addTrack(eventId, added.providerTrackId),
                );
              },
            );
          }
          if (state is TrackSearchError) {
            return Center(
              child: Text(
                state.message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            );
          }
          return const Center(child: Text('Search for tracks'));
        },
      ),
    );
  }
}
