import 'dart:async';

import 'package:flutter/material.dart';
import 'package:music_room/features/music_vote/presentation/widgets/mock_data.dart';
import 'package:music_room/features/music_vote/presentation/widgets/modals/delegation_bottom_sheet.dart';
import 'package:music_room/features/music_vote/presentation/widgets/modals/invite_bottom_sheet.dart';

/// The top header for the Live Room page.
///
/// Displays: back button · room title · LIVE badge · guest avatar stack ·
/// listener count · invite button · overflow menu.
class LiveHeader extends StatelessWidget {
  const LiveHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // ── Back button ──────────────────────────────────────────────────
          _CircleIconButton(
            icon: Icons.arrow_back,
            onPressed: () => Navigator.of(context).maybePop(),
            colorScheme: colorScheme,
            isDark: isDark,
          ),
          const SizedBox(width: 12),

          // ── Title + subtitle + LIVE badge ────────────────────────────────
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Friday Night Vi...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _LiveBadge(colorScheme: colorScheme),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const _GuestAvatarStack(
                      colors: mockGuestAvatarColors,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '+138 listening',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Action icons ─────────────────────────────────────────────────
          _CircleIconButton(
            icon: Icons.person_add_alt_1_outlined,
            onPressed: () => _showInviteSheet(context),
            colorScheme: colorScheme,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _CircleIconButton(
            icon: Icons.settings_outlined,
            onPressed: () => _showDelegationSheet(context),
            colorScheme: colorScheme,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  void _showInviteSheet(BuildContext context) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        barrierColor: Colors.black.withValues(alpha: 0.7),
        backgroundColor: Colors.transparent,
        builder: (_) => const InviteBottomSheet(),
      ),
    );
  }

  void _showDelegationSheet(BuildContext context) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        barrierColor: Colors.black.withValues(alpha: 0.7),
        backgroundColor: Colors.transparent,
        builder: (_) => const DelegationBottomSheet(),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Private sub-widgets
// ────────────────────────────────────────────────────────────────────────────

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Overlapping avatar circles showing guest profile pictures.
class _GuestAvatarStack extends StatelessWidget {
  const _GuestAvatarStack({required this.colors, required this.size});

  final List<int> colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    const overlap = 10.0;
    final totalWidth = size + (colors.length - 1) * (size - overlap);

    return SizedBox(
      width: totalWidth,
      height: size,
      child: Stack(
        children: List.generate(colors.length, (index) {
          return Positioned(
            left: index * (size - overlap),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(colors[index]),
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.person,
                  size: size * 0.55,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onPressed,
    required this.colorScheme,
    required this.isDark,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18),
        color: colorScheme.onSurface,
        onPressed: onPressed,
      ),
    );
  }
}
