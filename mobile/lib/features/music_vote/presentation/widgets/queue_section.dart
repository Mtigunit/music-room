import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:music_room/core/widgets/dynamic_search_bottom_sheet.dart';
import 'package:music_room/core/widgets/top_toast.dart';
import 'package:music_room/core/widgets/track_search_list_tile.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/events/presentation/state/track_search_cubit.dart';
import 'package:music_room/features/music_vote/data/models/event_detail_model.dart';
import 'package:music_room/features/music_vote/data/models/event_track_model.dart';
import 'package:music_room/features/music_vote/presentation/state/music_vote_cubit.dart';

/// The "Up Next" queue section with vote chips and controls.
///
/// Receives real [tracks] from the parent [BlocBuilder] and the [eventId]
/// for the "Add Song" CTA. Uses [policies] to enforce time-window and
/// GPS-based voting restrictions.
class QueueSection extends StatelessWidget {
  const QueueSection({
    required this.tracks,
    required this.policies,
    super.key,
    this.eventId,
    this.isHost = false,
    this.isEnded = false,
    this.canVote = true,
    this.currentTrackId,
  });

  final List<EventTrackModel> tracks;
  final EventPolicies policies;
  final String? eventId;
  final bool isHost;
  final bool isEnded;
  final bool canVote;

  /// The id of the track currently being played (from `state.currentTrack`).
  /// Used to render the "Now Playing" indicator and lock voting on that row.
  final String? currentTrackId;

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
          child: _AddSongButton(
            colorScheme: colorScheme,
            eventId: eventId,
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
                    key: ValueKey(track.id),
                    track: track,
                    rank: index + 1,
                    voteCount: track.voteScore,
                    hasVoted: track.isVoted,
                    isHost: isHost,
                    eventId: eventId,
                    isEnded: isEnded,
                    policies: policies,
                    canVote: canVote,
                    isNowPlaying:
                        currentTrackId != null && currentTrackId == track.id,
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

class QueueTrackItem extends StatefulWidget {
  const QueueTrackItem({
    required this.track,
    required this.rank,
    required this.hasVoted,
    required this.voteCount,
    required this.policies,
    this.isHost = false,
    this.isEnded = false,
    this.eventId,
    this.canVote = true,
    this.isNowPlaying = false,
    super.key,
  });

  final EventTrackModel track;
  final int rank;
  final bool hasVoted;
  final int voteCount;
  final EventPolicies policies;
  final bool isHost;
  final bool isEnded;
  final String? eventId;
  final bool canVote;
  final bool isNowPlaying;

  @override
  State<QueueTrackItem> createState() => _QueueTrackItemState();
}

class _QueueTrackItemState extends State<QueueTrackItem> {
  bool _isFetchingLocation = false;

  void _showRemoveConfirmation(BuildContext context) {
    if (widget.eventId == null) return;
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Remove Track?'),
            content: Text(
              "Are you sure you want to remove '${widget.track.title}' "
              'from the queue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  unawaited(
                    context.read<MusicVoteCubit>().removeTrack(
                      widget.eventId!,
                      widget.track.providerTrackId,
                    ),
                  );
                  Navigator.of(dialogContext).pop();
                },
                child: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Handles the vote action, gating on time-window and GPS policies.
  Future<void> _handleVote() async {
    // 1. Check time-window restriction
    if (!widget.policies.isVotingOpen) return;

    final cubit = context.read<MusicVoteCubit>();
    final voteType = widget.hasVoted ? 'none' : 'up';

    // 2. If locationAndTime policy is active, fetch GPS before voting
    if (widget.policies.locationAndTime) {
      setState(() => _isFetchingLocation = true);

      try {
        final position = await _acquirePosition();
        if (!mounted) return;

        setState(() => _isFetchingLocation = false);

        cubit.voteTrack(
          trackId: widget.track.trackId,
          voteType: voteType,
          lat: position.latitude,
          lng: position.longitude,
        );
      } on LocationServiceDisabledException {
        if (!mounted) return;
        setState(() => _isFetchingLocation = false);
        TopToast.show(
          context,
          'Please enable location services to vote at this event.',
        );
      } on PermissionDeniedException {
        if (!mounted) return;
        setState(() => _isFetchingLocation = false);
        TopToast.show(
          context,
          'This event requires your location to verify you are at the venue.',
        );
      } on Object {
        if (!mounted) return;
        setState(() => _isFetchingLocation = false);
        TopToast.show(
          context,
          'Unable to determine your location. Please try again.',
        );
      }
      return;
    }

    // 3. No location policy — vote directly
    cubit.voteTrack(
      trackId: widget.track.trackId,
      voteType: voteType,
    );
  }

  /// Acquires the device position, handling permission flow.
  Future<Position> _acquirePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const PermissionDeniedException('Location permission denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const PermissionDeniedException(
        'Location permissions are permanently denied',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E1E2E) : colorScheme.surface;
    final votingOpen = widget.policies.isVotingOpen;

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
          // Rank number / Now-Playing indicator
          SizedBox(
            width: 22,
            child: widget.isNowPlaying
                ? Icon(
                    Icons.volume_up_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  )
                : Text(
                    '${widget.rank}',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
          ),
          const SizedBox(width: 12),

          // Album art thumbnail
          _QueueTrackThumbnail(thumbnailUrl: widget.track.thumbnailUrl),
          const SizedBox(width: 12),

          // Track info
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.track.title,
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
                        '${widget.track.artist} · '
                        '${widget.track.formattedDuration}',
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

          // Remove button for host
          if (widget.isHost && !widget.isEnded) ...[
            IconButton(
              onPressed: () => _showRemoveConfirmation(context),
              icon: Icon(
                Icons.close_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.35),
                size: 20,
              ),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
          ],

          // Vote chip / Voting Closed / Not Invited / Now Playing /
          // Fetching Location
          if (_isFetchingLocation)
            const _LocationLoadingChip()
          else if (widget.isNowPlaying)
            _NowPlayingChip(colorScheme: colorScheme)
          else if (!widget.canVote)
            _VoteLockedChip(colorScheme: colorScheme)
          else if (!votingOpen)
            _VotingClosedChip(colorScheme: colorScheme)
          else
            _VoteChip(
              votes: widget.voteCount,
              hasVoted: widget.hasVoted,
              colorScheme: colorScheme,
              onVote: () => unawaited(_handleVote()),
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

/// Shown in place of the vote chip on the track that is currently playing.
/// Voting on the active track is disabled — votes only affect the queue.
class _NowPlayingChip extends StatelessWidget {
  const _NowPlayingChip({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.graphic_eq_rounded,
            size: 16,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 2),
          Text(
            'Live',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown in place of the vote chip when the user is not invited to a
/// restricted event (invitingOnly policy is active).
class _VoteLockedChip extends StatelessWidget {
  const _VoteLockedChip({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_rounded,
            size: 16,
            color: colorScheme.onSurface.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 2),
          Text(
            'Invite',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown in place of the vote chip when the event's time window has expired
/// or hasn't started yet.
class _VotingClosedChip extends StatelessWidget {
  const _VotingClosedChip({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_clock_rounded,
            size: 16,
            color: colorScheme.onSurface.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 2),
          Text(
            'Closed',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact loading spinner shown while fetching the user's GPS position.
class _LocationLoadingChip extends StatelessWidget {
  const _LocationLoadingChip();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'GPS',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: colorScheme.primary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
