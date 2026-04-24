import 'package:flutter/material.dart';

/// A reusable, premium empty-state placeholder widget.
///
/// Shows an icon, a message, and an optional action button.
/// Adapts to dark/light mode via [Theme.of(context)].
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    required this.icon,
    required this.message,
    super.key,
    this.actionLabel,
    this.onActionPressed,
  });

  /// The large centred icon.
  final IconData icon;

  /// Descriptive message shown below the icon.
  final String message;

  /// If non-null, a primary CTA button is rendered below the
  /// message with this label.
  final String? actionLabel;

  /// Callback for the action button.
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 40,
          vertical: 48,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Icon circle ───────────────────────────────
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withValues(
                  alpha: isDark ? 0.15 : 0.1,
                ),
              ),
              child: Icon(
                icon,
                size: 36,
                color: colorScheme.primary.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Message ───────────────────────────────────
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withValues(
                  alpha: 0.5,
                ),
                height: 1.5,
              ),
            ),

            // ── Action button ─────────────────────────────
            if (actionLabel != null && onActionPressed != null) ...[
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onActionPressed,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
