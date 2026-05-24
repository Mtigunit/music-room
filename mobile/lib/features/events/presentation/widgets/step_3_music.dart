import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/widgets/app_brand_icon.dart';
import 'package:music_room/core/widgets/dynamic_search_bottom_sheet.dart';
import 'package:music_room/core/widgets/responsive_layout.dart';
import 'package:music_room/core/widgets/track_search_list_tile.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/events/data/models/track_model.dart';
import 'package:music_room/features/events/presentation/state/track_search_cubit.dart';

class Step3Music extends StatelessWidget {
  const Step3Music({
    required this.selectedTracks,
    required this.onTracksChanged,
    required this.canContinue,
    required this.onNext,
    this.errorText,
    super.key,
  });

  final List<TrackModel> selectedTracks;
  final ValueChanged<List<TrackModel>> onTracksChanged;
  final bool canContinue;
  final String? errorText;
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
        canContinue: canContinue,
        errorText: errorText,
        onNext: onNext,
      ),
    );
  }
}

class _Step3MusicBody extends StatefulWidget {
  const _Step3MusicBody({
    required this.selectedTracks,
    required this.onTracksChanged,
    required this.canContinue,
    required this.onNext,
    this.errorText,
  });

  final List<TrackModel> selectedTracks;
  final ValueChanged<List<TrackModel>> onTracksChanged;
  final bool canContinue;
  final String? errorText;
  final VoidCallback onNext;

  @override
  State<_Step3MusicBody> createState() => _Step3MusicBodyState();
}

class _Step3MusicBodyState extends State<_Step3MusicBody> {
  String _playlistSearchQuery = '';

  void _removeTrack(int index) {
    final updatedTracks = List<TrackModel>.from(widget.selectedTracks)
      ..removeAt(index);
    widget.onTracksChanged(updatedTracks);
  }

  void _handleAddTrack(TrackModel track) {
    if (!widget.selectedTracks.any(
      (t) => t.providerTrackId == track.providerTrackId,
    )) {
      final updatedTracks = List<TrackModel>.from(widget.selectedTracks)
        ..add(track);
      widget.onTracksChanged(updatedTracks);

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

  Future<void> _showImportPlaylistModal(BuildContext context) async {
    setState(() => _playlistSearchQuery = '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: DynamicSearchBottomSheet(
                title: 'Import Playlist',
                subtitle: 'Choose from your saved collections',
                searchHintText: 'Search playlists or tags...',
                onSearchChanged: (val) {
                  setModalState(() => _playlistSearchQuery = val);
                },
                content: _PlaylistImportResults(
                  searchQuery: _playlistSearchQuery,
                  onPlaylistSelected: (name) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Importing $name...')),
                    );
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAddTracksModal(BuildContext context) async {
    final searchCubit = context.read<TrackSearchCubit>()
      ..searchTracks(''); // Clear previous results

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BlocProvider.value(
        value: searchCubit,
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: DynamicSearchBottomSheet(
                  title: 'Search Tracks',
                  subtitle: 'Find a specific song for your event',
                  searchHintText: 'Search for songs, artists, or albums...',
                  onSearchChanged: searchCubit.searchTracks,
                  onActionPressed: () => Navigator.of(context).pop(),
                  content: BlocBuilder<TrackSearchCubit, TrackSearchState>(
                    builder: (context, state) {
                      return _TrackSearchResults(
                        state: state,
                        selectedTracks: widget.selectedTracks,
                        onAddTrack: (track) {
                          _handleAddTrack(track);
                          // Refresh modal to show check icon
                          setModalState(() {});
                        },
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final size = ResponsiveLayout.resolveSize(width);
    final isCompact = size == ScreenSize.compact;
    final horizontalPadding = isCompact ? 16.0 : 24.0;
    final sectionGap = isCompact ? 20.0 : 24.0;
    final selectedCount = widget.selectedTracks.length;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Set up the initial music queue.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
          SizedBox(height: isCompact ? 14 : 16),
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
                    padding: EdgeInsets.symmetric(
                      vertical: isCompact ? 14 : 16,
                    ),
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
                    padding: EdgeInsets.symmetric(
                      vertical: isCompact ? 14 : 16,
                    ),
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
          SizedBox(height: sectionGap),

          Text(
            'SELECTED TRACKS ($selectedCount)',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: sectionGap),

          if (widget.selectedTracks.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'No tracks selected yet.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.selectedTracks.length,
              itemBuilder: (context, index) {
                final track = widget.selectedTracks[index];

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
                          child: const Center(child: AppBrandIcon(size: 20)),
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
          if (widget.errorText != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          SizedBox(height: isCompact ? 24 : 32),

          ElevatedButton(
            onPressed: widget.canContinue ? widget.onNext : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: EdgeInsets.symmetric(vertical: isCompact ? 14 : 16),
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
          SizedBox(height: isCompact ? 24 : 32),
        ],
      ),
    );
  }
}

class _TrackSearchResults extends StatelessWidget {
  const _TrackSearchResults({
    required this.state,
    required this.selectedTracks,
    required this.onAddTrack,
  });

  final TrackSearchState state;
  final List<TrackModel> selectedTracks;
  final ValueChanged<TrackModel> onAddTrack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (state is TrackSearchInitial) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_rounded,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'Search for songs or artists...',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
          (state as TrackSearchError).message,
          style: TextStyle(color: theme.colorScheme.error),
          textAlign: TextAlign.center,
        ),
      );
    } else if (state is TrackSearchLoaded) {
      final tracks = (state as TrackSearchLoaded).tracks;
      if (tracks.isEmpty) {
        return const Center(child: Text('No tracks found.'));
      }
      return ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: tracks.length,
        separatorBuilder: (context, _) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final track = tracks[index];
          final isAdded = selectedTracks.any(
            (t) => t.providerTrackId == track.providerTrackId,
          );
          return TrackSearchListTile(
            track: track,
            isAlreadyAdded: isAdded,
            onAddTapped: (addedTrack) async {
              onAddTrack(addedTrack);
            },
          );
        },
      );
    }
    return const SizedBox.shrink();
  }
}

class _PlaylistImportResults extends StatelessWidget {
  const _PlaylistImportResults({
    required this.searchQuery,
    required this.onPlaylistSelected,
  });

  final String searchQuery;
  final ValueChanged<String> onPlaylistSelected;

  static const List<Map<String, dynamic>> _mockPlaylists = [
    {
      'name': 'Late Night Driving',
      'tags': <String>['electronic', 'chill', 'synthwave'],
      'trackCount': 42,
    },
    {
      'name': 'Summer Techno',
      'tags': <String>['techno', 'dance', 'upbeat'],
      'trackCount': 108,
    },
    {
      'name': 'Moroccan Hits',
      'tags': <String>['pop', 'arabic', 'trending'],
      'trackCount': 25,
    },
    {
      'name': 'Gym Motivation',
      'tags': <String>['workout', 'hardstyle', 'bass'],
      'trackCount': 60,
    },
    {
      'name': 'Lo-fi Study',
      'tags': <String>['lo-fi', 'study', 'relax'],
      'trackCount': 200,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _mockPlaylists.where((pl) {
      final q = searchQuery.toLowerCase();
      if (q.isEmpty) return true;
      final nameMatches = (pl['name'] as String).toLowerCase().contains(q);
      final tagsMatch = (pl['tags'] as List<String>).any(
        (t) => t.toLowerCase().contains(q),
      );
      return nameMatches || tagsMatch;
    }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('No playlists found.'));
    }

    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final pl = filtered[index];
        final name = pl['name'] as String;
        final tags = (pl['tags'] as List<String>).join(', ');
        final count = pl['trackCount'] as int;

        return ListTile(
          onTap: () => onPlaylistSelected(name),
          leading: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.queue_music, color: theme.colorScheme.primary),
          ),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '$count tracks • $tags',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
        );
      },
    );
  }
}
