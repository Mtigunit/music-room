import 'package:flutter/material.dart';
import 'package:music_room/features/search/data/models/search_result_models.dart';

class SearchUserResultCard extends StatelessWidget {
  const SearchUserResultCard({required this.item, super.key});

  final SearchUserResultModel item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasAvatar = item.avatarUrl != null && item.avatarUrl!.isNotEmpty;

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
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.secondary.withValues(alpha: 0.8),
            ),
            child: hasAvatar
                ? ClipOval(
                    child: Image.network(
                      item.avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.person,
                        color: colorScheme.primary,
                      ),
                    ),
                  )
                : Icon(
                    Icons.person,
                    color: colorScheme.primary,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '@${item.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SearchChip(
                      label: item.subscriptionTier,
                      colorScheme: colorScheme,
                      filled: true,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.shortBio?.isNotEmpty == true
                      ? item.shortBio!
                      : 'Public profile and availability details.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.72),
                    height: 1.3,
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

class _SearchChip extends StatelessWidget {
  const _SearchChip({
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
