import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/widgets/app_brand_icon.dart';
import 'package:music_room/core/widgets/dynamic_search_bottom_sheet.dart';
import 'package:music_room/core/widgets/responsive_layout.dart';
import 'package:music_room/core/widgets/track_search_list_tile.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/events/data/models/track_model.dart';
import 'package:music_room/features/events/presentation/state/track_search_cubit.dart';
import 'package:music_room/features/playlist/data/datasources/playlist_remote_datasource.dart';
import 'package:music_room/features/playlist/domain/entities/playlist_entity.dart';
import 'package:music_room/features/profile/presentation/widgets/mock_payment_modal.dart';
import 'package:music_room/features/subscription/presentation/state/subscription_cubit.dart';

class Step3Music extends StatelessWidget {
  const Step3Music({
    required this.selectedTracks,
    required this.onTracksChanged,
    required this.canContinue,
    required this.onNext,
    this.selectedPlaylistIds = const [],
    this.onPlaylistIdsChanged,
    this.errorText,
    super.key,
  });

  final List<TrackModel> selectedTracks;
  final ValueChanged<List<TrackModel>> onTracksChanged;
  final List<String> selectedPlaylistIds;
  final ValueChanged<List<String>>? onPlaylistIdsChanged;
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
        selectedPlaylistIds: selectedPlaylistIds,
        onPlaylistIdsChanged: onPlaylistIdsChanged,
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
    this.selectedPlaylistIds = const [],
    this.onPlaylistIdsChanged,
    this.errorText,
  });

  final List<TrackModel> selectedTracks;
  final ValueChanged<List<TrackModel>> onTracksChanged;
  final List<String> selectedPlaylistIds;
  final ValueChanged<List<String>>? onPlaylistIdsChanged;
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
    final subState = context.read<SubscriptionCubit>().state;
    final isPremium = subState is SubscriptionLoaded && subState.isPremium;

    if (!isPremium) {
      final confirmed = await showMockPaymentModal(context);
      if (confirmed == true && context.mounted) {
        try {
          final success = await context.read<SubscriptionCubit>().upgradeTier(
            'PREMIUM',
          );
          if (success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Upgraded to Premium! You can now import playlists.',
                ),
              ),
            );
          }
        } on Object catch (_) {
          if (context.mounted) {
            final cubit = context.read<SubscriptionCubit>();
            await cubit.loadSubscription();
            final updatedState = cubit.state;

            if (context.mounted) {
              if (updatedState is SubscriptionLoaded &&
                  updatedState.isPremium) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Upgraded to Premium! You can now import playlists.',
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Failed to upgrade to Premium. Please try again.',
                    ),
                  ),
                );
              }
            }
          }
        }
      }
      return;
    }

    setState(() => _playlistSearchQuery = '');

    // Capture selected IDs so the modal can work with a local copy.
    final localSelectedIds = List<String>.from(widget.selectedPlaylistIds);

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
                  selectedPlaylistIds: localSelectedIds,
                  onPlaylistToggled: (playlistId) {
                    setModalState(() {
                      if (localSelectedIds.contains(playlistId)) {
                        localSelectedIds.remove(playlistId);
                      } else {
                        localSelectedIds.add(playlistId);
                      }
                    });
                  },
                ),
              ),
            ),
          );
        },
      ),
    );

    // When the bottom sheet is dismissed, propagate the selections.
    widget.onPlaylistIdsChanged?.call(localSelectedIds);
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
    final importedCount = widget.selectedPlaylistIds.length;

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
                  label: Text(
                    importedCount > 0
                        ? 'Import Playlist ($importedCount)'
                        : 'Import Playlist',
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
                      color: importedCount > 0
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primary.withValues(alpha: 0.55),
                      width: importedCount > 0 ? 2 : 1,
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

/// Fetches and displays the user's playlists from the backend.
///
/// Supports client-side filtering via [searchQuery] and multi-select via
/// [onPlaylistToggled].
class _PlaylistImportResults extends StatefulWidget {
  const _PlaylistImportResults({
    required this.searchQuery,
    required this.selectedPlaylistIds,
    required this.onPlaylistToggled,
  });

  final String searchQuery;
  final List<String> selectedPlaylistIds;
  final ValueChanged<String> onPlaylistToggled;

  @override
  State<_PlaylistImportResults> createState() => _PlaylistImportResultsState();
}

class _PlaylistImportResultsState extends State<_PlaylistImportResults> {
  late final IPlaylistRemoteDataSource _playlistDataSource;

  List<PlaylistEntity>? _playlists;
  bool _isLoading = true;
  String? _error;

  int _currentPage = 1;
  bool _hasMore = true;
  bool _isFetchingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _playlistDataSource = InjectionContainer().playlistRemoteDataSource;
    _scrollController.addListener(_onScroll);
    unawaited(_fetchPlaylists(isRefresh: true));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        !_isFetchingMore &&
        _hasMore) {
      unawaited(_fetchPlaylists());
    }
  }

  Future<void> _fetchPlaylists({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _isLoading = true;
        _error = null;
        _currentPage = 1;
        _hasMore = true;
      });
    } else {
      setState(() {
        _isFetchingMore = true;
        _error = null;
      });
    }

    try {
      final newPlaylists = await _playlistDataSource.fetchMyPlaylists(
        page: _currentPage,
      );
      if (!mounted) return;

      setState(() {
        if (isRefresh) {
          _playlists = newPlaylists;
        } else {
          _playlists = [...?_playlists, ...newPlaylists];
        }

        if (newPlaylists.length < 50) {
          _hasMore = false;
        } else {
          _currentPage++;
        }

        _isLoading = false;
        _isFetchingMore = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load playlists: $e';
        _isLoading = false;
        _isFetchingMore = false;
      });
    }
  }

  List<PlaylistEntity> get _filteredPlaylists {
    final all = _playlists ?? const <PlaylistEntity>[];
    final query = widget.searchQuery.trim().toLowerCase();
    if (query.isEmpty) return all;

    return all
        .where((playlist) {
          final nameMatch = playlist.name.toLowerCase().contains(query);
          final tagMatch = playlist.tags.any(
            (tag) => tag.toLowerCase().contains(query),
          );
          return nameMatch || tagMatch;
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: colorScheme.error.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              'Could not load playlists',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _fetchPlaylists(isRefresh: true),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final filtered = _filteredPlaylists;

    if ((_playlists ?? const []).isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_music_rounded,
              size: 56,
              color: colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            Text(
              'No playlists yet',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Create a playlist first to import tracks.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No playlists match "${widget.searchQuery}"',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      itemCount: filtered.length + (_isFetchingMore ? 1 : 0),
      separatorBuilder: (context, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        if (index == filtered.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final playlist = filtered[index];
        final isSelected = widget.selectedPlaylistIds.contains(playlist.id);

        return _PlaylistImportTile(
          playlist: playlist,
          isSelected: isSelected,
          onTap: () => widget.onPlaylistToggled(playlist.id),
        );
      },
    );
  }
}

/// A single playlist tile inside the import sheet.
class _PlaylistImportTile extends StatelessWidget {
  const _PlaylistImportTile({
    required this.playlist,
    required this.isSelected,
    required this.onTap,
  });

  final PlaylistEntity playlist;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.10)
                : colorScheme.onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.08),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Playlist thumbnail / icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: playlist.collageImageUrls.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          playlist.collageImageUrls.first,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(child: AppBrandIcon(size: 22)),
                        ),
                      )
                    : const Center(child: AppBrandIcon(size: 22)),
              ),
              const SizedBox(width: 14),

              // Name & track count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${playlist.trackCount} '
                      'track${playlist.trackCount == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),

              // Selection indicator
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isSelected
                    ? Icon(
                        Icons.check_circle_rounded,
                        key: const ValueKey('selected'),
                        color: colorScheme.primary,
                        size: 26,
                      )
                    : Icon(
                        Icons.radio_button_unchecked_rounded,
                        key: const ValueKey('unselected'),
                        color: colorScheme.onSurface.withValues(alpha: 0.25),
                        size: 26,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
