import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:music_room/features/music_vote/data/models/my_event_item.dart';

/// A compact, horizontal list-tile for the "My Events" dashboard.
///
/// The entire card is tappable. A subtle trailing icon indicates
/// affordance: a purple play icon for LIVE events, a grey
/// chevron for UPCOMING / ENDED.
class MyEventListTile extends StatelessWidget {
  const MyEventListTile({
    required this.event,
    super.key,
    this.onTap,
  });

  final MyEventItem event;

  /// Called when the user taps anywhere on the card.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      splashColor: colorScheme.primary.withValues(alpha: 0.08),
      highlightColor: colorScheme.primary.withValues(alpha: 0.04),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colorScheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
        ),
        child: Row(
          children: [
            // ── Thumbnail ──────────────────────────────
            _EventThumbnail(event: event),
            const SizedBox(width: 16),

            // ── Info column ────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Top row: Date & Badge
                  Row(
                    children: [
                      Text(
                        _formatDate(event.dateTime),
                        style: textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      _StatusBadge(event: event),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Middle text: Event name
                  Text(
                    event.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Bottom text: Host name & Status
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Host: ${event.hostName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.grey[400] : Colors.grey[500],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    // E.g. "Sun, 26 Apr at 5:00 PM"
    return DateFormat("EEE, dd MMM 'at' h:mm a").format(dt);
  }
}

// ────────────────────────────────────────────────────────────
// Thumbnail
// ────────────────────────────────────────────────────────────

class _EventThumbnail extends StatelessWidget {
  const _EventThumbnail({required this.event});

  final MyEventItem event;

  @override
  Widget build(BuildContext context) {
    final imageUrl = event.coverImageAsset;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 80,
            height: 80,
            child: hasImage
                ? Image.network(
                    imageUrl,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return _GradientPlaceholder(event: event);
                    },
                    errorBuilder: (_, _, _) =>
                        _GradientPlaceholder(event: event),
                  )
                : _GradientPlaceholder(event: event),
          ),
        ),

        // Pulsing live dot overlay on thumbnail
        if (event.isLive)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────
// Gradient placeholder (used when no cover image is available)
// ────────────────────────────────────────────────────────────

class _GradientPlaceholder extends StatelessWidget {
  const _GradientPlaceholder({required this.event});

  final MyEventItem event;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(event.coverColorHex),
            Color(event.coverColorHex).withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          event.isLive ? Icons.headphones : Icons.music_note,
          color: Colors.white.withValues(alpha: 0.85),
          size: 32,
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Status Badge
// ────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.event});

  final MyEventItem event;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bgColor;
    Color fgColor;
    String label;

    if (event.isLive) {
      bgColor = const Color(0xFFEF4444);
      fgColor = Colors.white;
      label = 'LIVE';
    } else if (event.isUpcoming) {
      bgColor = Theme.of(context).primaryColor;
      fgColor = Colors.white;
      label = 'UPCOMING';
    } else {
      bgColor = isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.04);
      fgColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);
      label = 'ENDED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (event.isLive) ...[
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fgColor,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
