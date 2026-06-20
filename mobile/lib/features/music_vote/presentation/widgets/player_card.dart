import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/utils/tag_genre_normalizer.dart';
import 'package:music_room/core/widgets/app_brand_icon.dart';
import 'package:music_room/features/music_vote/presentation/audio/room_audio_player.dart';
import 'package:music_room/features/music_vote/presentation/audio/track_preload.dart';
import 'package:music_room/features/music_vote/presentation/state/music_vote_cubit.dart';

/// The hero player section.
///
/// Displays: full-width art, overlay controls, track meta, and progress.
class PlayerCard extends StatefulWidget {
  const PlayerCard({
    super.key,
    this.isHost = false,
  });

  final bool isHost;

  @override
  State<PlayerCard> createState() => _PlayerCardState();
}

class _PlayerCardState extends State<PlayerCard> {
  /// Ticker used to advance the progress bar locally while the room is
  /// PLAYING **and** the audio engine has finished loading. The authoritative
  /// position arrives from `playback:status`.
  Timer? _progressTicker;

  /// Wall-clock time at which the current playback snapshot was applied.
  /// Combined with [_baselineMs] this gives the simulated playhead.
  late DateTime _snapshotAt;
  int _baselineMs = 0;
  int _progressMs = 0;

  String? _lastTrackId;
  String? _lastStatus;
  int? _lastPausedMs;
  DateTime? _lastStartedAt;
  bool _lastIsAudioLoading = false;

  @override
  void initState() {
    super.initState();
    _snapshotAt = DateTime.now();
  }

  @override
  void dispose() {
    _progressTicker?.cancel();
    super.dispose();
  }

  /// Re-syncs the ticker against the latest [MusicVoteState] snapshot.
  ///
  /// Position source:
  ///  - If playing and `currentTrackStartedAt` exists, use it with
  ///    `pausedPlaybackPositionMs` as an offset (resume-safe).
  ///  - If paused or `currentTrackStartedAt` is null, use
  ///    `pausedPlaybackPositionMs`.
  ///
  /// **Critical guard:** The progress ticker is NOT started while
  /// `isAudioLoading` is `true` — the audio engine hasn't emitted sound yet.
  void _syncWithState(MusicVoteState state) {
    final track = state.currentTrack;
    final status = state.playbackStatus;
    final isAudioLoading = state.isAudioLoading;
    final hasStartedAt = track?.currentTrackStartedAt != null;
    final isPlaying = status == 'PLAYING' || (status == null && hasStartedAt);

    final trackChanged = track?.id != _lastTrackId;
    final statusChanged = status != _lastStatus;
    final pausedMsChanged = track?.pausedPlaybackPositionMs != _lastPausedMs;
    final startedAtChanged = track?.currentTrackStartedAt != _lastStartedAt;
    final loadingChanged = isAudioLoading != _lastIsAudioLoading;

    if (!trackChanged &&
        !statusChanged &&
        !pausedMsChanged &&
        !startedAtChanged &&
        !loadingChanged) {
      return;
    }

    _lastTrackId = track?.id;
    _lastStatus = status;
    _lastPausedMs = track?.pausedPlaybackPositionMs;
    _lastStartedAt = track?.currentTrackStartedAt;
    _lastIsAudioLoading = isAudioLoading;

    _progressTicker?.cancel();

    if (track == null) {
      _progressMs = 0;
      _baselineMs = 0;
      _snapshotAt = DateTime.now();
      return;
    }

    // ── While audio is loading, freeze the progress bar at zero ──────────
    if (isAudioLoading) {
      // When loading a *new* track (track changed), reset progress to 0.
      // When resuming the same track, keep the last known position.
      if (trackChanged) {
        _progressMs = 0;
        _baselineMs = 0;
      }
      _snapshotAt = DateTime.now();
      return;
    }

    // ── Determine baseline and reference time ────────────────────────────
    final now = DateTime.now();
    final startedAt = track.currentTrackStartedAt ?? now;
    final pausedMs = track.pausedPlaybackPositionMs ?? 0;
    final computedMs = now.difference(startedAt).inMilliseconds + pausedMs;

    if (isPlaying) {
      _baselineMs = pausedMs;
      _snapshotAt = startedAt;
      _progressMs = computedMs.clamp(0, track.durationMs);
    } else {
      _baselineMs = pausedMs;
      _snapshotAt = now;
      _progressMs = pausedMs;
    }

    // ── Arm local ticker while playing (and NOT loading) ─────────────────
    if (isPlaying && !isAudioLoading && track.durationMs > 0) {
      _progressTicker = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) {
          if (!mounted) return;
          final elapsed = DateTime.now().difference(_snapshotAt).inMilliseconds;
          final next = (_baselineMs + elapsed).clamp(0, track.durationMs);
          if (next != _progressMs) {
            setState(() => _progressMs = next);
          }
        },
      );
    }
    // No setState for paused/stopped: _progressMs already set above, and
    // _syncWithState is called inside BlocBuilder (build phase).
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MusicVoteCubit, MusicVoteState>(
      buildWhen: (prev, curr) =>
          prev.currentTrack?.id != curr.currentTrack?.id ||
          prev.currentTrack?.title != curr.currentTrack?.title ||
          prev.currentTrack?.thumbnailUrl != curr.currentTrack?.thumbnailUrl ||
          prev.currentTrack?.durationMs != curr.currentTrack?.durationMs ||
          prev.playbackStatus != curr.playbackStatus ||
          prev.isAudioLoading != curr.isAudioLoading ||
          prev.currentTrack?.pausedPlaybackPositionMs !=
              curr.currentTrack?.pausedPlaybackPositionMs ||
          prev.currentTrack?.currentTrackStartedAt !=
              curr.currentTrack?.currentTrackStartedAt ||
          prev.listenerCount != curr.listenerCount ||
          prev.event?.coverImage != curr.event?.coverImage ||
          prev.event?.tags != curr.event?.tags ||
          prev.event?.status != curr.event?.status ||
          prev.event?.isDelegated != curr.event?.isDelegated,
      builder: (context, state) {
        _syncWithState(state);
        return _buildCard(context, state);
      },
    );
  }

  Widget _buildCard(BuildContext context, MusicVoteState state) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final track = state.currentTrack;
    final event = state.event;
    final status = state.playbackStatus;
    final hasStartedAt = track?.currentTrackStartedAt != null;
    final isPlaying = status == 'PLAYING' || (status == null && hasStartedAt);
    final isAudioLoading = state.isAudioLoading;
    // Playback controls are visible to the host AND to any user who has
    // accepted a delegation for this event (server confirms via the
    // `isDelegated` field on `GET /events/{id}`).
    final canControlPlayback = widget.isHost || (event?.isDelegated ?? false);
    final durationMs = track?.durationMs ?? 0;
    final progress = durationMs > 0
        ? (_progressMs / durationMs).clamp(0.0, 1.0)
        : 0.0;

    final size = MediaQuery.of(context).size;
    final heroHeight = (size.height * 0.42).clamp(240.0, 360.0);
    final trackTitle = track?.title ?? 'No Track Playing';
    final rawTag = (event?.tags.isNotEmpty ?? false) ? event!.tags.first : null;
    final genreTag = TagGenreNormalizer.toDisplayLabel(rawTag) ?? 'short wave';
    final listenerCount = state.listenerCount ?? 0;
    final statusLabel = event?.status == 'LIVE' ? 'Live' : 'Offline';
    final trackArt = track?.thumbnailUrl ?? '';
    final coverArt = event?.coverImage ?? '';
    final heroImageUrl = trackArt.isNotEmpty ? trackArt : coverArt;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: heroHeight,
            width: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(
                  child: _HeroImage(
                    imageUrl: heroImageUrl,
                    accent: colorScheme.primary,
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.2),
                        ],
                      ),
                    ),
                  ),
                ),
                if (canControlPlayback) ...[
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: _HeroPlayButton(
                      isPlaying: isPlaying,
                      isLoading: isAudioLoading,
                      accent: colorScheme.primary,
                      enabled: track != null && !isAudioLoading,
                      onTap: track != null && !isAudioLoading
                          ? () async {
                              final cubit = context.read<MusicVoteCubit>();
                              if (isPlaying) {
                                cubit.pause();
                              } else {
                                // To keep the progress bar in sync, we only
                                // emit play to the backend AFTER the audio
                                // is loaded.
                                final canPlay = await ensureTrackPreloaded(
                                  player: context.read<RoomAudioPlayer>(),
                                  cubit: cubit,
                                  providerTrackId: track.providerTrackId,
                                  startPositionMs:
                                      track.pausedPlaybackPositionMs ?? 0,
                                  isMounted: () => mounted,
                                  preload: widget.isHost,
                                );
                                if (canPlay) {
                                  cubit.play();
                                }
                              }
                            }
                          : null,
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: _HeroControlButton(
                      icon: Icons.skip_next_rounded,
                      filled: false,
                      accent: Colors.white,
                      enabled: track != null && !isAudioLoading,
                      onTap: track != null && !isAudioLoading
                          ? () async {
                              final cubit = context.read<MusicVoteCubit>();
                              final player = context.read<RoomAudioPlayer>();
                              final nextTrack = state.tracks.isNotEmpty
                                  ? state.tracks.first
                                  : null;

                              // Stop current audio immediately to prevent
                              // overlap between the old and new tracks.
                              if (widget.isHost) {
                                // Host stops its own audio player locally.
                                await player.stopImmediately();
                              } else {
                                // Delegated user emits pause so the host
                                // player stops immediately over the socket
                                // while the server fetches next track metadata.
                                cubit.pause();
                              }

                              final canNext =
                                  nextTrack != null &&
                                  await ensureTrackPreloaded(
                                    player: player,
                                    cubit: cubit,
                                    providerTrackId: nextTrack.providerTrackId,
                                    startPositionMs: 0,
                                    isMounted: () => mounted,
                                    preload: widget.isHost,
                                  );
                              if (canNext) {
                                cubit.next();
                              }
                            }
                          : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: const Color(0xFF101018),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trackTitle,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  '$genreTag | $listenerCount listening | $statusLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _ProgressBar(
                  progress: progress,
                  primaryColor: colorScheme.primary,
                  positionMs: _progressMs,
                  durationMs: durationMs,
                  isOnDark: true,
                  isLoading: isAudioLoading,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Hero media and controls
// ────────────────────────────────────────────────────────────────────────────

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.imageUrl, required this.accent});

  final String imageUrl;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.4),
            const Color(0xFF1B1025),
            const Color(0xFF0B0B12),
          ],
        ),
      ),
      child: const Center(child: AppBrandIcon(size: 72)),
    );
  }
}

/// Play / Pause hero button that shows a loading spinner when audio is
/// buffering.
class _HeroPlayButton extends StatelessWidget {
  const _HeroPlayButton({
    required this.isPlaying,
    required this.isLoading,
    required this.accent,
    required this.enabled,
    required this.onTap,
  });

  final bool isPlaying;
  final bool isLoading;
  final Color accent;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled || isLoading ? 1.0 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(36),
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent,
              border: Border.all(
                color: accent.withValues(alpha: 0.7),
                width: 1.5,
              ),
            ),
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(15),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 28,
                    color: Colors.white,
                  ),
          ),
        ),
      ),
    );
  }
}

class _HeroControlButton extends StatelessWidget {
  const _HeroControlButton({
    required this.icon,
    required this.filled,
    required this.accent,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool filled;
  final Color accent;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(36),
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? accent : Colors.black.withValues(alpha: 0.25),
              border: Border.all(
                color: filled
                    ? accent.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.9),
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              size: 28,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Progress bar
// ────────────────────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.progress,
    required this.primaryColor,
    required this.positionMs,
    required this.durationMs,
    this.isOnDark = false,
    this.isLoading = false,
  });

  final double progress;
  final Color primaryColor;
  final int positionMs;
  final int durationMs;
  final bool isOnDark;

  /// When `true`, the slider shows a pulsing / indeterminate visual.
  final bool isLoading;

  String _formatMs(int ms) {
    final totalSeconds = (ms ~/ 1000).clamp(0, 1 << 31);
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final activeTrack = isOnDark ? const Color(0xFFFFFFFF) : primaryColor;
    final inactiveTrack = isOnDark
        ? const Color(0x80FFFFFF)
        : colorScheme.onSurface.withValues(alpha: 0.15);
    final labelColor = isOnDark
        ? Colors.white.withValues(alpha: 0.75)
        : colorScheme.onSurface.withValues(alpha: 0.5);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2.5),
              child: LinearProgressIndicator(
                minHeight: 5,
                backgroundColor: inactiveTrack,
                color: activeTrack.withValues(alpha: 0.6),
              ),
            ),
          )
        else
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 5,
              trackShape: const RoundedRectSliderTrackShape(),
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 7,
                elevation: 0,
                pressedElevation: 0,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: activeTrack,
              disabledActiveTrackColor: activeTrack,
              inactiveTrackColor: inactiveTrack,
              disabledInactiveTrackColor: inactiveTrack,
              thumbColor: activeTrack,
              disabledThumbColor: activeTrack,
              overlayColor: activeTrack.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: progress,
              onChanged: null,
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isLoading ? '--:--' : _formatMs(positionMs),
                style: textTheme.bodySmall?.copyWith(
                  color: labelColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _formatMs(durationMs),
                style: textTheme.bodySmall?.copyWith(
                  color: labelColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
