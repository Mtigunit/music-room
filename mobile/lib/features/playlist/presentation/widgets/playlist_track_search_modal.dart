import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/app_back_button.dart';
import 'package:music_room/features/playlist/data/datasources/playlist_remote_datasource.dart';
import 'package:music_room/features/playlist/domain/entities/playlist_entity.dart';

class PlaylistTrackSearchModal extends StatefulWidget {
  const PlaylistTrackSearchModal({
    required this.dataSource,
    required this.onAddTrack,
    super.key,
  });

  final IPlaylistRemoteDataSource dataSource;
  final Future<bool> Function(TrackSearchEntity track) onAddTrack;

  @override
  State<PlaylistTrackSearchModal> createState() =>
      _PlaylistTrackSearchModalState();
}

class _PlaylistTrackSearchModalState extends State<PlaylistTrackSearchModal> {
  static const Duration _debounceDuration = Duration(milliseconds: 350);

  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;
  List<TrackSearchEntity> _results = const <TrackSearchEntity>[];
  bool _isLoading = false;
  String? _errorMessage;
  String? _addingTrackId;
  final Set<String> _addedTrackIds = <String>{};

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();

    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const <TrackSearchEntity>[];
        _errorMessage = null;
        _isLoading = false;
      });
      return;
    }

    _debounce = Timer(_debounceDuration, () {
      if (!mounted) {
        return;
      }
      unawaited(_search(query));
    });
  }

  Future<void> _search(String query) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await widget.dataSource.searchTracks(query);
      if (!mounted) {
        return;
      }

      setState(() {
        _results = results;
        _isLoading = false;
      });
    } on DioException {
      if (!mounted) {
        return;
      }

      setState(() {
        _results = const <TrackSearchEntity>[];
        _isLoading = false;
        _errorMessage = 'Song search failed. Please try again.';
      });
    } on Object {
      if (!mounted) {
        return;
      }

      setState(() {
        _results = const <TrackSearchEntity>[];
        _isLoading = false;
        _errorMessage = 'Song search failed. Please try again.';
      });
    }
  }

  Future<void> _handleAddTrack(TrackSearchEntity track) async {
    if (_addingTrackId != null) {
      return;
    }

    setState(() {
      _addingTrackId = track.providerTrackId;
    });

    await widget.onAddTrack(track);
    if (!mounted) {
      return;
    }

    setState(() {
      _addingTrackId = null;
    });

    // Modal remains open after adding a track so user can add more songs
    // User must manually close via the back button
    // Track successful addition
    setState(() {
      _addedTrackIds.add(track.providerTrackId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF151520) : colorScheme.surface;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    AppBackButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Add a Song',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                        Text(
                          'Search YouTube tracks and add to playlist',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _ModalSearchField(
                  controller: _searchController,
                  isDark: isDark,
                  colorScheme: colorScheme,
                  onChanged: _onQueryChanged,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _buildBody(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(ScrollController scrollController) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final hasQuery = _searchController.text.trim().isNotEmpty;
    if (!hasQuery) {
      return const Center(child: Text('Search for a song to add.'));
    }

    if (_results.isEmpty) {
      return const Center(
        child: Text('Song not found. Try a different query.'),
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _results.length,
      separatorBuilder: (_, index) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final track = _results[index];
        return _TrackSearchResultTile(
          track: track,
          isAdding: _addingTrackId == track.providerTrackId,
          isAdded: _addedTrackIds.contains(track.providerTrackId),
          onAdd: () {
            unawaited(_handleAddTrack(track));
          },
        );
      },
    );
  }
}

class _ModalSearchField extends StatelessWidget {
  const _ModalSearchField({
    required this.controller,
    required this.isDark,
    required this.colorScheme,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool isDark;
  final ColorScheme colorScheme;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final fieldBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);

    return Container(
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Icon(
              Icons.search,
              size: 20,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Song, artist, or album...',
                hintStyle: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.35),
                  fontSize: 15,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackSearchResultTile extends StatelessWidget {
  const _TrackSearchResultTile({
    required this.track,
    required this.onAdd,
    required this.isAdding,
    required this.isAdded,
  });

  final TrackSearchEntity track;
  final VoidCallback onAdd;
  final bool isAdding;
  final bool isAdded;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rowBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.02);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isAdding ? null : onAdd,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: rowBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 52,
                  height: 52,
                  color: colorScheme.secondary.withValues(alpha: 0.8),
                  child: track.thumbnailUrl != null
                      ? Image.network(
                          track.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.music_note,
                            color: Colors.white,
                            size: 24,
                          ),
                        )
                      : const Icon(
                          Icons.music_note,
                          color: Colors.white,
                          size: 24,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.artist ?? 'Unknown artist',
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isAdded
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.1),
                ),
                child: isAdding
                    ? const Padding(
                        padding: EdgeInsets.all(9),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        isAdded ? Icons.check : Icons.add,
                        size: 18,
                        color: isAdded
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface.withValues(alpha: 0.75),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
