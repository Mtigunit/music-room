import 'package:flutter/material.dart';
import 'package:music_room/features/playlist/presentation/widgets/playlist_collage_image.dart';
import 'package:music_room/features/search/data/models/search_result_models.dart';

class SearchPlaylistResultCard extends StatelessWidget {
  const SearchPlaylistResultCard({required this.item, super.key});

  final SearchPlaylistResultModel item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tags = item.tags.take(3).toList(growable: false);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlaylistCollageImage(
            thumbnailUrl: item.thumbnailUrl,
            collageImageUrls: item.collageImageUrls,
            borderRadius: BorderRadius.circular(22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ResultChip(
                      label: item.visibility,
                      colorScheme: colorScheme,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.description?.isNotEmpty == true
                      ? item.description!
                      : 'Curated by @${item.ownerName}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.72),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ResultChip(
                      label: '${item.trackCount} tracks',
                      colorScheme: colorScheme,
                      filled: true,
                    ),
                    _ResultChip(
                      label: '@${item.ownerName}',
                      colorScheme: colorScheme,
                    ),
                    if (tags.isNotEmpty)
                      ...tags.map(
                        (tag) => _ResultChip(
                          label: tag,
                          colorScheme: colorScheme,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({
    required this.label,
    required this.colorScheme,
    this.filled = false,
  });

  final String label;
  final ColorScheme colorScheme;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final background = filled
        ? colorScheme.primary.withValues(alpha: 0.1)
        : colorScheme.onSurface.withValues(alpha: 0.05);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: filled ? colorScheme.primary : colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
