import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/theme/app_theme.dart';
import 'package:music_room/features/music_vote/data/models/event_track_model.dart';
import 'package:music_room/features/music_vote/presentation/state/music_vote_cubit.dart';

/// The premium album-art player card.
///
/// Displays: album art with purple glow · track title · artist · progress bar
/// · playback controls (Shuffle, Previous, Play/Pause, Next, Repeat).
class PlayerCard extends StatefulWidget {
  const PlayerCard({
    super.key,
    this.isHost = false,
  });

  final bool isHost;

  @override
  State<PlayerCard> createState() => _PlayerCardState();
}

class _PlayerCardState extends State<PlayerCard>
    with SingleTickerProviderStateMixin {
  bool _isShuffle = false;
  bool _isRepeat = false;
  bool _isLiked = false;

  /// Ticker used to advance the progress bar locally while the room is
  /// PLAYING. The authoritative position arrives from `playback:status`.
  Timer? _progressTicker;

  /// Wall-clock time at which the current playback snapshot was applied.
  /// Combined with [_baselineMs] this gives the simulated playhead.
  DateTime? _snapshotAt;
  int _baselineMs = 0;
  int _progressMs = 0;

  String? _lastTrackId;
  String? _lastStatus;
  int? _lastPausedMs;
  DateTime? _lastStartedAt;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    unawaited(_pulseController.repeat(reverse: true));
    _pulseAnim = Tween<double>(begin: 0.6, end: 1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _progressTicker?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  /// Re-syncs the ticker against the latest [MusicVoteState] snapshot.
  ///
  /// Priority for position source:
  ///  1. `pausedPlaybackPositionMs` – present on pause AND on resume (wins)
  ///  2. `currentTrackStartedAt`    – present only on a fresh/initial play
  ///  3. 0 fallback
  void _syncWithState(MusicVoteState state) {
    final track = state.currentTrack;
    final status = state.playbackStatus;

    final trackChanged = track?.id != _lastTrackId;
    final statusChanged = status != _lastStatus;
    final pausedMsChanged = track?.pausedPlaybackPositionMs != _lastPausedMs;
    final startedAtChanged = track?.currentTrackStartedAt != _lastStartedAt;

    if (!trackChanged &&
        !statusChanged &&
        !pausedMsChanged &&
        !startedAtChanged) {
      return;
    }

    _lastTrackId = track?.id;
    _lastStatus = status;
    _lastPausedMs = track?.pausedPlaybackPositionMs;
    _lastStartedAt = track?.currentTrackStartedAt;

    _progressTicker?.cancel();

    if (track == null) {
      _progressMs = 0;
      _baselineMs = 0;
      _snapshotAt = DateTime.now();
      return;
    }

    // ── Determine baseline and reference time ────────────────────────────
    if (track.pausedPlaybackPositionMs != null) {
      // Paused position OR resumed-from-pause: tick forward from that offset.
      _baselineMs = track.pausedPlaybackPositionMs!;
      _snapshotAt = DateTime.now();
    } else if (track.currentTrackStartedAt != null) {
      // Fresh start: wall-clock start is the reference, baseline is 0.
      _baselineMs = 0;
      _snapshotAt = track.currentTrackStartedAt;
    } else {
      _baselineMs = 0;
      _snapshotAt = DateTime.now();
    }

    // ── Compute immediate display position (no setState; called in build) ───
    if (status == 'PLAYING') {
      final elapsed = DateTime.now().difference(_snapshotAt!).inMilliseconds;
      _progressMs = (_baselineMs + elapsed).clamp(0, track.durationMs);
    } else {
      _progressMs = _baselineMs;
    }

    // ── Arm local ticker while playing ──────────────────────────────────
    if (status == 'PLAYING' && track.durationMs > 0) {
      _progressTicker = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) {
          if (!mounted) return;
          final elapsed = _snapshotAt == null
              ? 0
              : DateTime.now().difference(_snapshotAt!).inMilliseconds;
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
          prev.playbackStatus != curr.playbackStatus ||
          prev.currentTrack?.pausedPlaybackPositionMs !=
              curr.currentTrack?.pausedPlaybackPositionMs ||
          prev.currentTrack?.currentTrackStartedAt !=
              curr.currentTrack?.currentTrackStartedAt,
      builder: (context, state) {
        _syncWithState(state);
        return _buildCard(context, state);
      },
    );
  }

  Widget _buildCard(BuildContext context, MusicVoteState state) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E1E2E) : colorScheme.surface;
    final track = state.currentTrack;
    final isPlaying = state.playbackStatus == 'PLAYING';
    final durationMs = track?.durationMs ?? 0;
    final progress = durationMs > 0
        ? (_progressMs / durationMs).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Album Art with glow ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _AlbumArtGlow(
              pulseAnim: _pulseAnim,
              colorScheme: colorScheme,
              isDark: isDark,
              track: track,
            ),
          ),

          // ── Track info + Like ───────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track?.title ?? 'No Track Playing',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        track?.artist ?? 'Waiting for music...',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Like button (local-only for now)
                Tooltip(
                  message: _isLiked ? 'Unlike track' : 'Like track',
                  child: IconButton(
                    onPressed: () => setState(() => _isLiked = !_isLiked),
                    style: IconButton.styleFrom(
                      fixedSize: const Size(38, 38),
                      backgroundColor: _isLiked
                          ? Colors.red.withValues(alpha: 0.15)
                          : colorScheme.onSurface.withValues(alpha: 0.08),
                    ),
                    icon: Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: _isLiked
                          ? Colors.red
                          : colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Progress bar ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _ProgressBar(
              progress: progress,
              primaryColor: colorScheme.primary,
              positionMs: _progressMs,
              durationMs: durationMs,
            ),
          ),

          // ── Playback Controls (host only) ──────────────────────────
          if (widget.isHost)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: _PlaybackControls(
                isPlaying: isPlaying,
                isShuffle: _isShuffle,
                isRepeat: _isRepeat,
                colorScheme: colorScheme,
                onPlayPause: () {
                  final cubit = context.read<MusicVoteCubit>();
                  if (isPlaying) {
                    cubit.pause();
                  } else {
                    cubit.play();
                  }
                },
                onShuffle: () => setState(() => _isShuffle = !_isShuffle),
                onRepeat: () => setState(() => _isRepeat = !_isRepeat),
                onPrevious: () {}, // Backend does not expose previous yet.
                onNext: () => context.read<MusicVoteCubit>().next(),
              ),
            )
          else
            const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Album art with animated glow
// ────────────────────────────────────────────────────────────────────────────

class _AlbumArtGlow extends StatelessWidget {
  const _AlbumArtGlow({
    required this.pulseAnim,
    required this.colorScheme,
    required this.isDark,
    this.track,
  });

  final Animation<double> pulseAnim;
  final ColorScheme colorScheme;
  final bool isDark;
  final EventTrackModel? track;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(
                  alpha: isDark
                      ? 0.55 * pulseAnim.value
                      : 0.3 * pulseAnim.value,
                ),
                blurRadius: 40,
                spreadRadius: 8,
              ),
              BoxShadow(
                color: AppTheme.primaryColor.withValues(
                  alpha: isDark
                      ? 0.25 * pulseAnim.value
                      : 0.12 * pulseAnim.value,
                ),
                blurRadius: 80,
                spreadRadius: 16,
              ),
            ],
          ),
          child: child,
        );
      },
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: track != null && track!.thumbnailUrl.isNotEmpty
              ? Image.network(
                  track!.thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      _MockAlbumArt(primaryColor: colorScheme.primary),
                )
              : _MockAlbumArt(primaryColor: colorScheme.primary),
        ),
      ),
    );
  }
}

/// Painted mock album art (neon/synthwave aesthetic matching the screenshot).
class _MockAlbumArt extends StatelessWidget {
  const _MockAlbumArt({required this.primaryColor});

  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0.1, -0.2),
          radius: 1.2,
          colors: [
            primaryColor.withValues(alpha: 0.24),
            const Color(0xFF2A0040),
            const Color(0xFF0D001A),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _SynthwavePainter(),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: Text(
              'Synthwave',
              style: TextStyle(
                fontFamily: 'sans-serif',
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: primaryColor,
                letterSpacing: 2,
                shadows: [
                  Shadow(
                    color: primaryColor.withValues(alpha: 0.8),
                    blurRadius: 20,
                  ),
                  Shadow(
                    color: primaryColor.withValues(alpha: 0.45),
                    blurRadius: 40,
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

class _SynthwavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Ground neon circle
    final circlePaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(Offset(cx, cy + 30), size.width * 0.28, circlePaint);

    // Inner circle fill
    final innerFill = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF7C3AED).withValues(alpha: 0.4),
              const Color(0xFF7C3AED).withValues(alpha: 0.1),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(cx, cy + 30),
              radius: size.width * 0.28,
            ),
          );
    canvas.drawCircle(Offset(cx, cy + 30), size.width * 0.28, innerFill);

    // Neon border frame
    final framePaint = Paint()
      ..color = const Color(0xFFB300FF).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final rect = Rect.fromLTWH(16, 16, size.width - 32, size.height - 32);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      framePaint,
    );

    // Glow lines at the bottom
    for (var i = 0; i < 6; i++) {
      final y = size.height * 0.72 + i * 12.0;
      final linePaint = Paint()
        ..color = const Color(0xFFB300FF).withValues(alpha: 0.3 - i * 0.04)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(24, y),
        Offset(size.width - 24, y),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
  });

  final double progress;
  final Color primaryColor;
  final int positionMs;
  final int durationMs;

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: primaryColor,
            inactiveTrackColor: colorScheme.onSurface.withValues(alpha: 0.15),
            thumbColor: Colors.transparent,
            overlayColor: primaryColor.withValues(alpha: 0.15),
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
                _formatMs(positionMs),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
              Text(
                _formatMs(durationMs),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Playback controls row
// ────────────────────────────────────────────────────────────────────────────

class _PlaybackControls extends StatelessWidget {
  const _PlaybackControls({
    required this.isPlaying,
    required this.isShuffle,
    required this.isRepeat,
    required this.colorScheme,
    required this.onPlayPause,
    required this.onShuffle,
    required this.onRepeat,
    required this.onPrevious,
    required this.onNext,
  });

  final bool isPlaying;
  final bool isShuffle;
  final bool isRepeat;
  final ColorScheme colorScheme;
  final VoidCallback onPlayPause;
  final VoidCallback onShuffle;
  final VoidCallback onRepeat;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final activeColor = colorScheme.primary;
    final dimColor = colorScheme.onSurface.withValues(alpha: 0.4);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Shuffle
        IconButton(
          onPressed: onShuffle,
          icon: Icon(
            Icons.shuffle,
            size: 22,
            color: isShuffle ? activeColor : dimColor,
          ),
        ),

        // Previous
        IconButton(
          onPressed: onPrevious,
          icon: Icon(
            Icons.skip_previous_rounded,
            size: 32,
            color: colorScheme.onSurface,
          ),
        ),

        // Play / Pause (prominent button)
        GestureDetector(
          onTap: onPlayPause,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: activeColor,
              boxShadow: [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 32,
              color: Colors.white,
            ),
          ),
        ),

        // Next
        IconButton(
          onPressed: onNext,
          icon: Icon(
            Icons.skip_next_rounded,
            size: 32,
            color: colorScheme.onSurface,
          ),
        ),

        // Repeat
        IconButton(
          onPressed: onRepeat,
          icon: Icon(
            Icons.repeat,
            size: 22,
            color: isRepeat ? activeColor : dimColor,
          ),
        ),
      ],
    );
  }
}
