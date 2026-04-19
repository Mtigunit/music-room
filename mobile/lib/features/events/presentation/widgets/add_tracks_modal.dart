import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/features/events/data/models/track_model.dart';
import 'package:music_room/features/events/presentation/state/track_search_cubit.dart';

class AddTracksModal extends StatefulWidget {
  const AddTracksModal({
    required this.initialSelectedTracks,
    required this.onTracksChanged,
    super.key,
  });

  final List<TrackModel> initialSelectedTracks;
  final ValueChanged<List<TrackModel>> onTracksChanged;

  @override
  State<AddTracksModal> createState() => _AddTracksModalState();
}

class _AddTracksModalState extends State<AddTracksModal> {
  late List<TrackModel> _localTracks;

  @override
  void initState() {
    super.initState();
    _localTracks = List.from(widget.initialSelectedTracks);
  }

  void _handleAddTrack(TrackModel track) {
    if (!_localTracks.any((t) => t.providerTrackId == track.providerTrackId)) {
      setState(() {
        _localTracks.add(track);
      });
      widget.onTracksChanged(_localTracks);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Track added!'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Search Tracks',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (value) {
              context.read<TrackSearchCubit>().searchTracks(value);
            },
            decoration: InputDecoration(
              hintText: 'Search for songs, artists...',
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
              prefixIcon: Icon(
                Icons.search,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: theme.colorScheme.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Search Results Area
          Expanded(
            child: BlocBuilder<TrackSearchCubit, TrackSearchState>(
              builder: (context, state) {
                if (state is TrackSearchInitial) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 64,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Search for songs, artists, or albums...',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                } else if (state is TrackSearchLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is TrackSearchError) {
                  return Center(
                    child: Text(
                      state.message,
                      style: TextStyle(color: theme.colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  );
                } else if (state is TrackSearchLoaded) {
                  if (state.tracks.isEmpty) {
                    return Center(
                      child: Text(
                        'No tracks found.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: state.tracks.length,
                    itemBuilder: (context, index) {
                      final track = state.tracks[index];
                      final isAdded = _localTracks.any(
                        (t) => t.providerTrackId == track.providerTrackId,
                      );
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            track.thumbnailUrl,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 48,
                                height: 48,
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.music_note),
                              );
                            },
                          ),
                        ),
                        title: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            isAdded ? Icons.check : Icons.add_circle_outline,
                            color: isAdded
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                          ),
                          onPressed: isAdded
                              ? null
                              : () => _handleAddTrack(track),
                        ),
                      );
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}
