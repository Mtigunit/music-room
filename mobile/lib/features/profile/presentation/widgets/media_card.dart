import 'package:flutter/material.dart';
import 'package:music_room/core/utils/image_url.dart';
import 'package:music_room/core/utils/tag_genre_normalizer.dart';
import 'package:music_room/features/playlist/presentation/widgets/playlist_collage_image.dart';

final class PlaylistCardData {
  const PlaylistCardData({
    required this.id,
    required this.name,
    required this.thumbnailUrl,
    required this.visibility,
    required this.trackCount,
    required this.tags,
    this.collageImageUrls = const [],
  });

  final String id;
  final String name;
  final String? thumbnailUrl;
  final String visibility;
  final int trackCount;
  final List<String> tags;
  final List<String> collageImageUrls;
}

class MediaCard extends StatelessWidget {
  const MediaCard({
    required this.data,
    this.onTap,
    super.key,
  });

  final PlaylistCardData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(colorScheme),
      child: Row(
        children: [
          _Thumbnail(data: data),
          const SizedBox(width: 14),
          Expanded(
            child: _PlaylistContent(
              playlist: data,
              theme: theme,
              colorScheme: colorScheme,
              hasAction: onTap != null,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.data});

  final PlaylistCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: PlaylistCollageImage(
        thumbnailUrl: resolveImageUrl(data.thumbnailUrl),
        collageImageUrls: data.collageImageUrls,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _PlaylistContent extends StatelessWidget {
  const _PlaylistContent({
    required this.playlist,
    required this.theme,
    required this.colorScheme,
    required this.hasAction,
  });

  final PlaylistCardData playlist;
  final ThemeData theme;
  final ColorScheme colorScheme;
  final bool hasAction;

  @override
  Widget build(BuildContext context) {
    final normalizedTags = playlist.tags
        .map(TagGenreNormalizer.toDisplayLabel)
        .whereType<String>()
        .take(3)
        .toList(growable: false);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                playlist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              hasAction
                  ? Icons.chevron_right_rounded
                  : Icons.playlist_play_rounded,
              size: 20,
              color: colorScheme.secondary.withValues(alpha: 0.42),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${playlist.visibility} · ${playlist.trackCount} tracks',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.68),
          ),
        ),
        if (normalizedTags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: normalizedTags
                .map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tag,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ],
    );
  }
}

BoxDecoration _cardDecoration(ColorScheme colorScheme) => BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      colorScheme.surface,
      colorScheme.surfaceContainerHighest.withValues(alpha: 0.82),
    ],
  ),
  borderRadius: BorderRadius.circular(24),
  border: Border.all(
    color: colorScheme.onSurface.withValues(alpha: 0.08),
  ),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ],
);

// Image URL resolution moved to `core/utils/image_url.dart`.
