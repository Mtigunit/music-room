import 'dart:async';

import 'package:flutter/material.dart';
import 'package:music_room/features/music_vote/presentation/widgets/mock_data.dart';
import 'package:music_room/features/music_vote/presentation/widgets/modals/add_song_bottom_sheet.dart';

/// The "Up Next" queue section with vote chips and controls.
class QueueSection extends StatefulWidget {
  const QueueSection({super.key});

  @override
  State<QueueSection> createState() => _QueueSectionState();
}

class _QueueSectionState extends State<QueueSection> {
  /// Track which items the user has voted for (by track ID).
  final Set<int> _votedIds = {};

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Full-width Add Song CTA ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _AddSongButton(colorScheme: colorScheme),
        ),
        const SizedBox(height: 20),

        // ── Section header ──────────────────────────────────────────────────
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
                '${mockQueueTracks.length} tracks',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Queue list ──────────────────────────────────────────────────────
        ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: mockQueueTracks.length,
          separatorBuilder: (_, separator) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final track = mockQueueTracks[index];
            final hasVoted = _votedIds.contains(track.id);

            return QueueTrackItem(
              track: track,
              hasVoted: hasVoted,
              onVote: () {
                setState(() {
                  if (hasVoted) {
                    _votedIds.remove(track.id);
                  } else {
                    _votedIds.add(track.id);
                  }
                });
                debugPrint('Voted for: ${track.title}');
              },
            );
          },
        ),
      ],
    );
  }
}
// ────────────────────────────────────────────────────────────────────────────
// Full-width Add Song CTA button
// ────────────────────────────────────────────────────────────────────────────

class _AddSongButton extends StatelessWidget {
  const _AddSongButton({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        unawaited(
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            barrierColor: Colors.black.withValues(alpha: 0.7),
            backgroundColor: Colors.transparent,
            builder: (_) => const AddSongBottomSheet(),
          ),
        );
      },
      child: Container(
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
          borderRadius: BorderRadius.circular(14),
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
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Individual queue track item
// ────────────────────────────────────────────────────────────────────────────

class QueueTrackItem extends StatelessWidget {
  const QueueTrackItem({
    required this.track,
    required this.hasVoted,
    required this.onVote,
    super.key,
  });

  final MockTrack track;
  final bool hasVoted;
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
              '${track.rank}',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Album art thumbnail
          _TrackThumbnail(colorHex: track.colorHex),
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
                        '${track.artist} · ${track.addedBy}',
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
            votes: track.votes,
            hasVoted: hasVoted,
            colorScheme: colorScheme,
            onVote: onVote,
          ),
        ],
      ),
    );
  }
}

/// Small album thumbnail with colored background.
class _TrackThumbnail extends StatelessWidget {
  const _TrackThumbnail({required this.colorHex});

  final int colorHex;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 48,
        height: 48,
        color: Color(colorHex),
        child: const Icon(
          Icons.music_note,
          size: 22,
          color: Colors.white,
        ),
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

    return GestureDetector(
      onTap: onVote,
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
    );
  }
}
