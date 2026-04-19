import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/features/search/data/datasources/search_remote_datasource.dart';

enum TrackAction { addToEvent, saveToPlaylist }

class TrackResultCard extends StatelessWidget {
  const TrackResultCard({required this.item, super.key});

  final SearchResultItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
          TrackThumbnail(imageUrl: item.imageUrl),
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
                  '${item.subtitle}'
                  '${item.meta != null && item.meta!.isNotEmpty ? ' · '
                            '${item.meta}' : ''}',
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

  void _handleTrackAction(BuildContext context, TrackAction action) {
    switch (action) {
      case TrackAction.addToEvent:
        AppSnackbar.showInfo(
          context,
          'Add to event feature coming soon.',
        );
        return;
      case TrackAction.saveToPlaylist:
        AppSnackbar.showInfo(
          context,
          'Save to playlist feature coming soon.',
        );
        return;
    }
  }
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
