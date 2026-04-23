import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:music_room/features/events/data/models/my_event_item.dart';

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

    final cardBg = isDark ? const Color(0xFF1E1E2E) : colorScheme.surface;

    const borderRadius = BorderRadius.all(Radius.circular(16));

    return Material(
      color: cardBg,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        splashColor: colorScheme.primary.withValues(alpha: 0.08),
        highlightColor: colorScheme.primary.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(
              color: colorScheme.onSurface.withValues(alpha: 0.07),
            ),
          ),
          child: Row(
            children: [
              // ── Thumbnail ──────────────────────────────
              _EventThumbnail(event: event),
              const SizedBox(width: 14),

              // ── Info column ────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Event name + status badge
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            event.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(event: event),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Host name
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 13,
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            event.hostName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.55,
                              ),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Date / time
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 13,
                          color: colorScheme.onSurface.withValues(alpha: 0.35),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(event.dateTime),
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(
                              alpha: 0.45,
                            ),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Trailing icon ──────────────────────────
              const SizedBox(width: 4),
              _TrailingIcon(
                event: event,
                colorScheme: colorScheme,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = dt.difference(now);

    // Currently live
    if (diff.isNegative && diff.inHours.abs() < 12) {
      return 'Started ${diff.inMinutes.abs()}m ago';
    }

    // Today
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today, ${DateFormat.jm().format(dt)}';
    }

    // Tomorrow
    final tomorrow = now.add(const Duration(days: 1));
    if (dt.year == tomorrow.year &&
        dt.month == tomorrow.month &&
        dt.day == tomorrow.day) {
      return 'Tomorrow, ${DateFormat.jm().format(dt)}';
    }

    return DateFormat('MMM d, h:mm a').format(dt);
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
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 60,
            height: 60,
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
                size: 26,
              ),
            ),
          ),
        ),

        // Pulsing live dot overlay on thumbnail
        if (event.isLive)
          Positioned(
            top: 4,
            right: 4,
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
      bgColor = const Color(0xFFEF4444).withValues(alpha: 0.15);
      fgColor = const Color(0xFFEF4444);
      label = 'LIVE';
    } else if (event.isUpcoming) {
      bgColor = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.06);
      fgColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
      label = 'UPCOMING';
    } else {
      bgColor = isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.04);
      fgColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35);
      label = 'ENDED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
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
                color: Color(0xFFEF4444),
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
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Trailing Icon (replaces the old Enter Room button)
// ────────────────────────────────────────────────────────────

class _TrailingIcon extends StatelessWidget {
  const _TrailingIcon({
    required this.event,
    required this.colorScheme,
  });

  final MyEventItem event;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    if (event.isLive) {
      return Icon(
        Icons.play_circle_fill_rounded,
        size: 28,
        color: colorScheme.primary,
      );
    }

    return Icon(
      Icons.chevron_right_rounded,
      size: 24,
      color: colorScheme.onSurface.withValues(alpha: 0.3),
    );
  }
}
