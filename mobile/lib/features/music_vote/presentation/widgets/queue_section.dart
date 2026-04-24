import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/widgets/dynamic_search_bottom_sheet.dart';
import 'package:music_room/core/widgets/track_search_list_tile.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/events/presentation/state/track_search_cubit.dart';
import 'package:music_room/features/music_vote/data/models/event_track_model.dart';
import 'package:music_room/features/music_vote/presentation/state/music_vote_cubit.dart';

/// The "Up Next" queue section with vote chips and controls.
///
/// Receives real [tracks] from the parent [BlocBuilder] and the [eventId]
/// for the "Add Song" CTA.
class QueueSection extends StatefulWidget {
  const QueueSection({
    required this.tracks,
    super.key,
    this.eventId,
  });

  final List<EventTrackModel> tracks;
  final String? eventId;

  @override
  State<QueueSection> createState() => _QueueSectionState();
}

class _QueueSectionState extends State<QueueSection> {
  /// Track which items the user has voted for (by track ID).
  final Set<String> _votedIds = {};

  /// Local mutable copy of vote counts for UI responsiveness.
  final Map<String, int> _voteCounts = {};

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tracks = widget.tracks;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Full-width Add Song CTA ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _AddSongButton(
            colorScheme: colorScheme,
            eventId: widget.eventId,
          ),
        ),
        const SizedBox(height: 20),

        // ── Section header ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Up Next',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              Text(
                '${tracks.length} tracks',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Queue list ──────────────────────────────────────────────────
        if (tracks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Center(
              child: Text(
                'No tracks in queue yet.\nTap "+ Add Song" to get started!',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(tracks.length, (index) {
                final track = tracks[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == tracks.length - 1 ? 0 : 8,
                  ),
                  child: QueueTrackItem(
                    track: track,
                    rank: index + 1,
                    voteCount: _voteCounts[track.id] ?? track.voteScore,
                    hasVoted: _votedIds.contains(track.id),
                    onVote: () {
                      setState(() {
                        final recomputedHasVoted = _votedIds.contains(track.id);
                        final currentVotes =
                            _voteCounts[track.id] ?? track.voteScore;
                        if (recomputedHasVoted) {
                          _votedIds.remove(track.id);
                          _voteCounts[track.id] = currentVotes - 1;
                        } else {
                          _votedIds.add(track.id);
                          _voteCounts[track.id] = currentVotes + 1;
                        }
                      });
                      if (kDebugMode) {
                        debugPrint('Voted for: ${track.title}');
                      }
                    },
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Full-width Add Song CTA button
// ────────────────────────────────────────────────────────────────────────────

class _AddSongButton extends StatelessWidget {
  const _AddSongButton({
    required this.colorScheme,
    this.eventId,
  });

  final ColorScheme colorScheme;
  final String? eventId;

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.all(Radius.circular(14));

    return Semantics(
      button: true,
      label: 'Add song',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: () => _showAddSongSheet(context),
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary,
                  colorScheme.primary.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: borderRadius,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 18, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Add Song',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddSongSheet(BuildContext context) {
    final musicVoteCubit = context.read<MusicVoteCubit>();
    final resolvedEventId = eventId;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        barrierColor: Colors.black.withValues(alpha: 0.7),
        backgroundColor: Colors.transparent,
        builder: (_) => BlocProvider(
          create: (_) => TrackSearchCubit(
            remoteDataSource: InjectionContainer().trackRemoteDataSource,
          ),
          child: _AddSongSearchSheet(
            eventId: resolvedEventId,
            musicVoteCubit: musicVoteCubit,
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Add Song Sheet using DynamicSearchBottomSheet + TrackSearchCubit
// ────────────────────────────────────────────────────────────────────────────

class _AddSongSearchSheet extends StatelessWidget {
  const _AddSongSearchSheet({
    required this.musicVoteCubit,
    this.eventId,
  });

  final String? eventId;
  final MusicVoteCubit musicVoteCubit;

  @override
  Widget build(BuildContext context) {
    return DynamicSearchBottomSheet(
      title: 'Search Tracks',
      subtitle: 'Find a specific song for your event',
      searchHintText: 'Search for songs, artists, or albums...',
      onSearchChanged: (query) {
        context.read<TrackSearchCubit>().searchTracks(query);
      },
      content: BlocBuilder<TrackSearchCubit, TrackSearchState>(
        builder: (context, state) {
          if (state is TrackSearchLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is TrackSearchError) {
            return Center(
              child: Text(
                state.message,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.7),
                ),
              ),
            );
          }

          if (state is TrackSearchLoaded) {
            if (state.tracks.isEmpty) {
              return Center(
                child: Text(
                  'No results found.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: state.tracks.length,
              separatorBuilder: (context, separatorIndex) =>
                  const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final track = state.tracks[index];
                return TrackSearchListTile(
                  track: track,
                  onAddTapped: (addedTrack) async {
                    final id = eventId;
                    if (id != null && id.isNotEmpty) {
                      await musicVoteCubit.addTrack(
                        id,
                        addedTrack.providerTrackId,
                      );
                      // Don't pop immediately so the user can see
                      // the success state
                    }
                  },
                );
              },
            );
          }

          // Initial state — prompt
          return Center(
            child: Text(
              'Start typing to search for tracks',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Individual queue track item
// ────────────────────────────────────────────────────────────────────────────

class QueueTrackItem extends StatelessWidget {
  const QueueTrackItem({
    required this.track,
    required this.rank,
    required this.hasVoted,
    required this.voteCount,
    required this.onVote,
    super.key,
  });

  final EventTrackModel track;
  final int rank;
  final bool hasVoted;
  final int voteCount;
  final VoidCallback onVote;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E1E2E) : colorScheme.surface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.07),
        ),
      ),
      child: Row(
        children: [
          // Rank number
          SizedBox(
            width: 22,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Album art thumbnail
          _QueueTrackThumbnail(thumbnailUrl: track.thumbnailUrl),
          const SizedBox(width: 12),

          // Track info
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        '${track.artist} · ${track.formattedDuration}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Vote chip
          _VoteChip(
            votes: voteCount,
            hasVoted: hasVoted,
            colorScheme: colorScheme,
            onVote: onVote,
          ),
        ],
      ),
    );
  }
}

/// Queue track thumbnail — shows the real image from [thumbnailUrl],
/// or a music note icon if the URL is empty / fails to load.
class _QueueTrackThumbnail extends StatelessWidget {
  const _QueueTrackThumbnail({required this.thumbnailUrl});

  final String thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: thumbnailUrl.isNotEmpty
          ? Image.network(
              thumbnailUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => _fallback(colorScheme),
            )
          : _fallback(colorScheme),
    );
  }

  Widget _fallback(ColorScheme colorScheme) {
    return Container(
      width: 48,
      height: 48,
      color: colorScheme.primary.withValues(alpha: 0.2),
      child: Icon(
        Icons.music_note,
        size: 22,
        color: colorScheme.primary,
      ),
    );
  }
}

/// Up-arrow + vote count chip (handles voted state).
class _VoteChip extends StatelessWidget {
  const _VoteChip({
    required this.votes,
    required this.hasVoted,
    required this.colorScheme,
    required this.onVote,
  });

  final int votes;
  final bool hasVoted;
  final ColorScheme colorScheme;
  final VoidCallback onVote;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = hasVoted
        ? colorScheme.primary.withValues(alpha: 0.2)
        : (isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05));
    final fgColor = hasVoted
        ? colorScheme.primary
        : colorScheme.onSurface.withValues(alpha: 0.6);

    return Semantics(
      button: true,
      selected: hasVoted,
      label: hasVoted ? 'Remove upvote' : 'Upvote track',
      value: '$votes votes',
      child: Tooltip(
        message: hasVoted ? 'Remove upvote' : 'Upvote track',
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onVote,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasVoted
                      ? colorScheme.primary.withValues(alpha: 0.4)
                      : Colors.transparent,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_upward_rounded, size: 16, color: fgColor),
                  const SizedBox(height: 2),
                  Text(
                    '$votes',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: fgColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
