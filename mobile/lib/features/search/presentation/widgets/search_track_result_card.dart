import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/events/domain/entities/my_event_item_model.dart';
import 'package:music_room/features/playlist/domain/entities/playlist_entity.dart'
    show PlaylistEntity, TrackSearchEntity;
import 'package:music_room/features/search/data/models/search_result_models.dart';
import 'package:music_room/features/search/presentation/widgets/modals/select_event_sheet.dart';
import 'package:music_room/features/search/presentation/widgets/modals/select_playlist_sheet.dart';

enum TrackAction { addToEvent, saveToPlaylist }

class SearchTrackResultCard extends StatelessWidget {
  const SearchTrackResultCard({required this.item, super.key});

  final SearchTrackResultModel item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final artist = item.artist ?? 'Unknown Artist';
    final duration = item.durationMs > 0
        ? ' · ${_formatDuration(item.durationMs)}'
        : '';
    final subtitle = '$artist$duration';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          TrackThumbnail(imageUrl: item.thumbnailUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<TrackAction>(
            tooltip: 'Track actions',
            offset: const Offset(0, 45),
            elevation: 10,
            constraints: const BoxConstraints(minWidth: 250),
            splashRadius: 20,
            onSelected: (action) => _handleTrackAction(context, action),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            color: colorScheme.surface.withValues(alpha: 0.98),
            surfaceTintColor: colorScheme.surface.withValues(alpha: 0.98),
            padding: EdgeInsets.zero,
            itemBuilder: (context) => [
              const PopupMenuItem<TrackAction>(
                value: TrackAction.addToEvent,
                child: TrackMenuActionItem(
                  icon: Icons.event,
                  title: 'Add to event',
                  subtitle: 'Queue this track for one of your events',
                ),
              ),
              PopupMenuDivider(
                height: 4,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
              ),
              const PopupMenuItem<TrackAction>(
                value: TrackAction.saveToPlaylist,
                child: TrackMenuActionItem(
                  icon: Icons.playlist_add,
                  title: 'Save to playlist',
                  subtitle: 'Add this track to one of your playlists',
                ),
              ),
            ],
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.14),
                    colorScheme.primary.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Icon(
                Icons.more_horiz_rounded,
                color: colorScheme.primary,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleTrackAction(
    BuildContext context,
    TrackAction action,
  ) async {
    switch (action) {
      case TrackAction.addToEvent:
        await _addToEvent(context);
        return;
      case TrackAction.saveToPlaylist:
        await _saveToPlaylist(context);
        return;
    }
  }

  Future<void> _saveToPlaylist(BuildContext context) async {
    final selected = await showModalBottomSheet<PlaylistEntity>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const SelectPlaylistSheet(),
    );

    if (!context.mounted) return;
    if (selected == null) return;

    final ds = InjectionContainer().playlistRemoteDataSource;
    final track = TrackSearchEntity(
      providerTrackId: item.providerTrackId,
      title: item.title,
      durationMs: item.durationMs,
      artist: item.artist,
      thumbnailUrl: item.thumbnailUrl,
    );

    // show ephemeral progress dialog (fire-and-forget). Capture the
    // navigator before awaiting network work so we can always attempt to
    // dismiss the dialog in `finally`, even if this widget becomes
    // unmounted while the request is in-flight.
    final navigator = Navigator.of(context);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      ),
    );

    String? errorMsg;
    try {
      await ds.addTrackToPlaylist(selected.id, track);
    } on DioException catch (e) {
      final data = e.response?.data;
      errorMsg = data is Map<String, dynamic>
          ? data['message'] as String?
          : null;
    } on Object {
      errorMsg = 'Unable to add track to playlist.';
    } finally {
      if (navigator.mounted && navigator.canPop()) {
        navigator.pop(); // dismiss progress
      }
    }

    if (!context.mounted) return;
    if (errorMsg == null) {
      AppSnackbar.showSuccess(context, 'Added to "${selected.name}"');
    } else {
      AppSnackbar.showError(context, errorMsg);
    }
  }

  Future<void> _addToEvent(BuildContext context) async {
    final selected = await showModalBottomSheet<MyEventItemModel>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const SelectEventSheet(),
    );

    if (!context.mounted) return;
    if (selected == null) return;

    final eventId = selected.id;
    final ds = InjectionContainer().musicVoteRemoteDataSource;

    final navigator = Navigator.of(context);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      ),
    );

    String? errorMsg;
    try {
      await ds.addTrackToEvent(eventId, item.providerTrackId);
    } on DioException catch (e) {
      final data = e.response?.data;
      errorMsg = data is Map<String, dynamic>
          ? data['message'] as String?
          : null;
    } on Object {
      errorMsg = 'Unable to queue track.';
    } finally {
      if (navigator.mounted && navigator.canPop()) {
        navigator.pop();
      }
    }

    if (!context.mounted) return;
    if (errorMsg == null) {
      AppSnackbar.showSuccess(context, 'Queued in "${selected.name}"');
    } else {
      AppSnackbar.showError(context, errorMsg);
    }
  }
}

String _formatDuration(int durationMs) {
  // Use truncation to avoid rounding up near the boundary.
  final totalSeconds = durationMs ~/ 1000;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
}

class TrackMenuActionItem extends StatelessWidget {
  const TrackMenuActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: colorScheme.primary.withValues(alpha: 0.6),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.62),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TrackThumbnail extends StatelessWidget {
  const TrackThumbnail({this.imageUrl, super.key});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: colorScheme.secondary.withValues(alpha: 0.85),
      ),
      child: hasImage
          ? ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.music_note,
                  color: colorScheme.primary,
                ),
              ),
            )
          : Icon(
              Icons.music_note,
              color: colorScheme.primary,
            ),
    );
  }
}
