import 'package:flutter/material.dart';
import 'package:music_room/features/music_vote/presentation/widgets/mock_data.dart';

/// "Manage Room & Delegation" bottom sheet (V.2.2).
///
/// Displays a list of room members. Each row has an avatar, username,
/// role/premium badges, and a [Switch] to grant playback-control delegation.
/// All state is local and mock — wire to a BLoC / WebSocket in the next phase.
class DelegationBottomSheet extends StatefulWidget {
  const DelegationBottomSheet({super.key});

  @override
  State<DelegationBottomSheet> createState() => _DelegationBottomSheetState();
}

class _DelegationBottomSheetState extends State<DelegationBottomSheet> {
  /// Mutable copy so each Switch can be toggled independently in the UI.
  late final List<_DelegateState> _users;

  @override
  void initState() {
    super.initState();
    _users = mockDelegateUsers
        .map((u) => _DelegateState(user: u, isDelegated: u.isDelegated))
        .toList();
  }

  // Derived stats
  int get _djCount => _users.where((u) => u.isDelegated).length;
  int get _voterCount => _users.length - _djCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sheetBg = isDark ? const Color(0xFF151520) : colorScheme.surface;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Drag handle ─────────────────────────────────────────────
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Title + subtitle ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Manage Room & Delegation',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Friday Night Vibes · ${_users.length} members',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Info banner ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _InfoBanner(
                  colorScheme: colorScheme,
                  isDark: isDark,
                ),
              ),
              const SizedBox(height: 20),

              // ── Stats row ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _StatsRow(
                  djCount: _djCount,
                  voterCount: _voterCount,
                  total: _users.length,
                  colorScheme: colorScheme,
                  isDark: isDark,
                ),
              ),
              const SizedBox(height: 16),

              // ── User list ────────────────────────────────────────────────
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  itemCount: _users.length,
                  separatorBuilder: (_, separator) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final state = _users[index];
                    return _DelegateUserRow(
                      state: state,
                      colorScheme: colorScheme,
                      isDark: isDark,
                      onToggle: (value) {
                        setState(() => state.isDelegated = value);
                        debugPrint(
                          'Delegation toggled for '
                          '${state.user.username}: $value',
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Mutable wrapper — needed so Switch state can be flipped in ListView
// ---------------------------------------------------------------------------

class _DelegateState {
  _DelegateState({required this.user, required this.isDelegated});

  final MockDelegateUser user;
  bool isDelegated;
}

// ---------------------------------------------------------------------------
// Info banner
// ---------------------------------------------------------------------------

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.colorScheme, required this.isDark});

  final ColorScheme colorScheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bannerBg = isDark
        ? colorScheme.primary.withValues(alpha: 0.12)
        : colorScheme.primary.withValues(alpha: 0.06);
    // In dark mode use a high-contrast onSurface so the text is readable
    // against the very dark sheet background. In light mode the primary
    // tint reads clearly on a white surface.
    final textColor = isDark
        ? colorScheme.onSurface.withValues(alpha: 0.85)
        : colorScheme.primary.withValues(alpha: 0.9);
    final iconColor = isDark ? colorScheme.primary : colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: iconColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Toggle DJ control to let someone manage '
              'playback. Voters can only upvote tracks in the queue.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats row (1 DJ · 5 Voters · 6 Total)
// ---------------------------------------------------------------------------

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.djCount,
    required this.voterCount,
    required this.total,
    required this.colorScheme,
    required this.isDark,
  });

  final int djCount;
  final int voterCount;
  final int total;
  final ColorScheme colorScheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.04);

    Widget stat(String value, String label) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.onSurface.withValues(alpha: 0.07),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.primary,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        stat('$djCount', 'DJs'),
        const SizedBox(width: 10),
        stat('$voterCount', 'Voters'),
        const SizedBox(width: 10),
        stat('$total', 'Total'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Individual delegate row
// ---------------------------------------------------------------------------

class _DelegateUserRow extends StatelessWidget {
  const _DelegateUserRow({
    required this.state,
    required this.colorScheme,
    required this.isDark,
    required this.onToggle,
  });

  final _DelegateState state;
  final ColorScheme colorScheme;
  final bool isDark;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Neutral surface bg — never tinted purple. A subtle border highlights
    // the delegated state instead, keeping the list clean and readable.
    final rowBg = isDark
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
        : colorScheme.surface;
    final delegatedBorder = colorScheme.primary.withValues(alpha: 0.4);
    final neutralBorder = colorScheme.onSurface.withValues(alpha: 0.08);
    final user = state.user;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          width: state.isDelegated ? 1.5 : 1,
          color: state.isDelegated ? delegatedBorder : neutralBorder,
        ),
      ),
      child: Row(
        children: [
          // ── Avatar ────────────────────────────────────────────────────
          _UserAvatar(
            username: user.username,
            colorHex: user.colorHex,
            isDelegated: state.isDelegated,
            primaryColor: colorScheme.primary,
          ),
          const SizedBox(width: 12),

          // ── Username + badges ─────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.username,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    _RoleBadge(
                      label: user.role,
                      isDj: user.role == 'DJ',
                      colorScheme: colorScheme,
                    ),
                    if (user.isPremium) ...[
                      const SizedBox(width: 6),
                      _PremiumBadge(colorScheme: colorScheme),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ── Delegation switch ─────────────────────────────────────────
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: state.isDelegated,
                onChanged: onToggle,
                activeThumbColor: Colors.white,
                activeTrackColor: colorScheme.primary,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: colorScheme.onSurface.withValues(
                  alpha: 0.2,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              Text(
                'Delegate',
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  // Always use the secondary onSurface variant — it's
                  // readable in dark mode and doesn't compete with content.
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// User avatar with optional DJ crown indicator
// ---------------------------------------------------------------------------

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({
    required this.username,
    required this.colorHex,
    required this.isDelegated,
    required this.primaryColor,
  });

  final String username;
  final int colorHex;
  final bool isDelegated;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color(colorHex),
            border: isDelegated
                ? Border.all(color: primaryColor, width: 2)
                : null,
          ),
          child: Center(
            child: Text(
              username.replaceAll('@', '')[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
        ),
        if (isDelegated)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.headset_mic_rounded,
                size: 10,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Role badge ("DJ" / "Voter")
// ---------------------------------------------------------------------------

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({
    required this.label,
    required this.isDj,
    required this.colorScheme,
  });

  final String label;
  final bool isDj;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    // Solid primary bg for DJ; neutral grey for Voter.
    final bg = isDj
        ? colorScheme.primary
        : colorScheme.onSurface.withValues(alpha: 0.08);
    // onPrimary guarantees white text on the solid purple DJ badge.
    final fg = isDj
        ? colorScheme.onPrimary
        : colorScheme.onSurface.withValues(alpha: 0.55);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Premium badge (gold star pill)
// ---------------------------------------------------------------------------

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 10, color: Color(0xFFFFC107)),
          SizedBox(width: 3),
          Text(
            'Premium',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFFC107),
            ),
          ),
        ],
      ),
    );
  }
}
