import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/widgets/top_toast.dart';
import 'package:music_room/features/music_vote/data/models/event_detail_model.dart';
import 'package:music_room/features/music_vote/presentation/state/music_vote_cubit.dart';
import 'package:music_room/features/music_vote/presentation/widgets/live_header.dart';
import 'package:music_room/features/music_vote/presentation/widgets/player_card.dart';
import 'package:music_room/features/music_vote/presentation/widgets/queue_section.dart';
import 'package:music_room/features/music_vote/presentation/widgets/skeletons/music_vote_skeleton.dart';

/// The primary scrollable view for the Live Music Vote room.
///
/// Composes: [LiveHeader] → [PlayerCard] → [QueueSection].
/// Uses [BlocBuilder] to show loading / error / loaded states.
class MusicVoteView extends StatelessWidget {
  const MusicVoteView({
    super.key,
    this.eventId,
    this.isHost = false,
  });

  final String? eventId;
  final bool isHost;

  @override
  Widget build(BuildContext context) {
    return BlocListener<MusicVoteCubit, MusicVoteState>(
      listenWhen: (prev, curr) => prev.error != curr.error,
      listener: (context, state) {
        if (state.error != null && state.event != null) {
          TopToast.show(context, state.error!);
          context.read<MusicVoteCubit>().clearError();
        }
      },
      child: BlocBuilder<MusicVoteCubit, MusicVoteState>(
        builder: (context, state) {
          // Loading state
          if (state.isLoading) {
            return const MusicVoteSkeleton();
          }

          // Error state (with retry)
          if (state.error != null && state.event == null) {
            return Scaffold(
              body: SafeArea(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _StickyHeaderDelegate(
                        child: _HeaderBackground(
                          child: LiveHeader(
                            eventId: eventId,
                            isHost: isHost,
                          ),
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
                ),
              ),
            );
          }

          // Loaded state (LIVE)
          final eventName = state.event?.name;

          return Scaffold(
            body: SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── Sticky header ─────────────────────────────────────
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyHeaderDelegate(
                      child: _HeaderBackground(
                        child: LiveHeader(
                          eventId: eventId,
                          eventName: eventName,
                          isHost: isHost,
                        ),
                      ),
                    ),
                  ),

                  // ── Player card (still mocked) ────────────────────────
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverToBoxAdapter(child: PlayerCard(isHost: isHost)),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // ── Queue / Up Next ───────────────────────────────────
                  SliverToBoxAdapter(
                    child: QueueSection(
                      tracks: state.tracks,
                      policies: state.event?.policies ?? const EventPolicies(),
                      eventId: eventId,
                      isHost: isHost,
                      isEnded: state.event?.status == 'ENDED',
                      canVote:
                          !(state.event?.policies.invitingOnly ?? false) ||
                          (state.event?.isInvited ?? false) ||
                          (state.event?.isHost ?? false),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
          );
        },
      ),
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
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return oldDelegate is! _StickyHeaderDelegate ||
        oldDelegate.child != child ||
        oldDelegate.minExtent != minExtent ||
        oldDelegate.maxExtent != maxExtent;
  }
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
