import 'package:flutter/material.dart';
import 'package:music_room/features/music_vote/presentation/widgets/live_header.dart';
import 'package:music_room/features/music_vote/presentation/widgets/player_card.dart';
import 'package:music_room/features/music_vote/presentation/widgets/queue_section.dart';

/// The primary scrollable view for the Live Music Vote room.
///
/// Composes: [LiveHeader] → [PlayerCard] → [QueueSection].
/// All data is mock/hardcoded at this stage. Real WebSocket and API
/// integration will be layered on top in a subsequent phase.
class MusicVoteView extends StatelessWidget {
  const MusicVoteView({
    super.key,
    this.eventId,
  });

  final String? eventId;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Sticky header ──────────────────────────────────────────────────
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyHeaderDelegate(
            child: _HeaderBackground(
              child: LiveHeader(eventId: eventId),
            ),
          ),
        ),

        // ── Player card ────────────────────────────────────────────────────
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        const SliverToBoxAdapter(child: PlayerCard()),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),

        // ── Queue / Up Next ────────────────────────────────────────────────
        const SliverToBoxAdapter(child: QueueSection()),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Sticky header delegate
// ────────────────────────────────────────────────────────────────────────────

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _StickyHeaderDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 70;

  @override
  double get maxExtent => 84;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) =>
      oldDelegate.child != child;
}

/// Adds the scaffold background color behind the sticky header so it
/// doesn't look transparent when content scrolls underneath.
class _HeaderBackground extends StatelessWidget {
  const _HeaderBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      alignment: Alignment.center,
      child: child,
    );
  }
}
