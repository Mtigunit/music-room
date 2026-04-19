import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/events/data/models/track_model.dart';
import 'package:music_room/features/events/presentation/state/track_search_cubit.dart';
import 'package:music_room/features/events/presentation/widgets/add_tracks_modal.dart';
import 'package:music_room/features/events/presentation/widgets/import_playlist_modal.dart';

class Step3Music extends StatelessWidget {
  const Step3Music({
    required this.selectedTracks,
    required this.onTracksChanged,
    required this.onNext,
    super.key,
  });

  final List<TrackModel> selectedTracks;
  final ValueChanged<List<TrackModel>> onTracksChanged;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TrackSearchCubit(
        remoteDataSource: InjectionContainer().trackRemoteDataSource,
      ),
      child: _Step3MusicBody(
        selectedTracks: selectedTracks,
        onTracksChanged: onTracksChanged,
        onNext: onNext,
      ),
    );
  }
}

class _Step3MusicBody extends StatelessWidget {
  const _Step3MusicBody({
    required this.selectedTracks,
    required this.onTracksChanged,
    required this.onNext,
  });

  final List<TrackModel> selectedTracks;
  final ValueChanged<List<TrackModel>> onTracksChanged;
  final VoidCallback onNext;

  void _removeTrack(int index) {
    final updatedTracks = List<TrackModel>.from(selectedTracks)
      ..removeAt(index);
    onTracksChanged(updatedTracks);
  }

  Future<void> _showImportPlaylistModal(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: const ImportPlaylistModal(),
      ),
    );
  }

  Future<void> _showAddTracksModal(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => BlocProvider.value(
        value: context.read<TrackSearchCubit>(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.9,
          child: AddTracksModal(
            initialSelectedTracks: selectedTracks,
            onTracksChanged: onTracksChanged,
          ),
        ),
      ),
    );

    if (context.mounted) {
      context.read<TrackSearchCubit>().searchTracks('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCount = selectedTracks.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Set up the initial music queue.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showAddTracksModal(context),
                        icon: const Icon(Icons.search),
                        label: const Text('Add Tracks'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                          textStyle: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showImportPlaylistModal(context),
                        icon: const Icon(Icons.playlist_add),
                        label: const Text(
                          'Import Playlist',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.55,
                            ),
                          ),
                          foregroundColor: theme.colorScheme.primary,
                          textStyle: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text(
                  'SELECTED TRACKS ($selectedCount)',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: selectedTracks.isEmpty
                      ? Center(
                          child: Text(
                            'No tracks selected yet.',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: selectedTracks.length,
                          itemBuilder: (context, index) {
                            final track = selectedTracks[index];

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              minVerticalPadding: 8,
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  track.thumbnailUrl,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 48,
                                      height: 48,
                                      color: theme.colorScheme.primaryContainer,
                                      child: Icon(
                                        Icons.music_note,
                                        color: theme.colorScheme.primary,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              title: Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => _removeTrack(index),
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
          child: ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: const Text('Continue'),
          ),
        ),
      ],
    );
  }
}
