import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/features/music_vote/presentation/state/music_vote_cubit.dart';
import 'package:music_room/features/music_vote/presentation/widgets/live_header.dart';
import 'package:music_room/features/music_vote/presentation/widgets/player_card.dart';
import 'package:music_room/features/music_vote/presentation/widgets/queue_section.dart';

/// The primary scrollable view for the Live Music Vote room.
///
/// Composes: [LiveHeader] → [PlayerCard] → [QueueSection].
/// Uses [BlocBuilder] to show loading / error / loaded states.
class MusicVoteView extends StatelessWidget {
  const MusicVoteView({
    super.key,
    this.eventId,
  });

  final String? eventId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MusicVoteCubit, MusicVoteState>(
      builder: (context, state) {
        // Loading state
        if (state.isLoading) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyHeaderDelegate(
                  child: _HeaderBackground(
                    child: LiveHeader(eventId: eventId),
                  ),
                ),
              ),
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        }

        // Error state (with retry)
        if (state.error != null && state.event == null) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyHeaderDelegate(
                  child: _HeaderBackground(
                    child: LiveHeader(eventId: eventId),
                  ),
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorBody(
                  message: state.error!,
                  onRetry: eventId != null && eventId!.isNotEmpty
                      ? () => context.read<MusicVoteCubit>().loadRoom(
                          eventId!,
                        )
                      : null,
                ),
              ),
            ],
          );
        }

        // Loaded state
        final eventName = state.event?.name;

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Sticky header ────────────────────────────────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyHeaderDelegate(
                child: _HeaderBackground(
                  child: LiveHeader(
                    eventId: eventId,
                    eventName: eventName,
                  ),
                ),
              ),
            ),

            // ── Player card (still mocked) ───────────────────────────────
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            const SliverToBoxAdapter(child: PlayerCard()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── Queue / Up Next ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: QueueSection(
                tracks: state.tracks,
                eventId: eventId,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Error body with retry button
// ────────────────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: colorScheme.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
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
