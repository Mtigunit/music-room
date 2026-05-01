import 'package:flutter/material.dart';
import 'package:music_room/features/search/data/models/search_result_models.dart';

class SearchEventResultCard extends StatelessWidget {
  const SearchEventResultCard({required this.item, super.key});

  final SearchEventResultModel item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasImage =
        item.coverImageUrl != null && item.coverImageUrl!.isNotEmpty;
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
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: colorScheme.secondary.withValues(alpha: 0.8),
            ),
            child: hasImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      item.coverImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.event,
                        color: colorScheme.primary,
                      ),
                    ),
                  )
                : Icon(
                    Icons.event,
                    color: colorScheme.primary,
                  ),
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
                    _EventChip(
                      label: item.status,
                      colorScheme: colorScheme,
                      filled: true,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.description?.isNotEmpty == true
                      ? item.description!
                      : 'Hosted by ${item.hostName}',
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
                    _EventChip(
                      label: _formatDateLabel(item.startDate),
                      colorScheme: colorScheme,
                    ),
                    _EventChip(
                      label: '@${item.hostName}',
                      colorScheme: colorScheme,
                    ),
                    if (item.locationLabel != null)
                      _EventChip(
                        label: item.locationLabel!,
                        colorScheme: colorScheme,
                      ),
                    if (tags.isNotEmpty)
                      ...tags.map(
                        (tag) => _EventChip(
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

String _formatDateLabel(String? rawValue) {
  if (rawValue == null || rawValue.trim().isEmpty) {
    return 'Scheduled event';
  }

  final parsed = DateTime.tryParse(rawValue);
  if (parsed == null) {
    return rawValue;
  }

  final local = parsed.toLocal();
  final month = _monthName(local.month);
  final day = local.day;
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '$month $day, $hour:$minute $period';
}

String _monthName(int month) {
  switch (month) {
    case 1:
      return 'Jan';
    case 2:
      return 'Feb';
    case 3:
      return 'Mar';
    case 4:
      return 'Apr';
    case 5:
      return 'May';
    case 6:
      return 'Jun';
    case 7:
      return 'Jul';
    case 8:
      return 'Aug';
    case 9:
      return 'Sep';
    case 10:
      return 'Oct';
    case 11:
      return 'Nov';
    case 12:
      return 'Dec';
    default:
      return 'Date';
  }
}

class _EventChip extends StatelessWidget {
  const _EventChip({
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
