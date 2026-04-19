import 'dart:async';

import 'package:flutter/material.dart';
import 'package:music_room/core/theme/app_theme.dart';
import 'package:music_room/features/music_vote/presentation/widgets/mock_data.dart';

/// The premium album-art player card.
///
/// Displays: album art with purple glow · track title · artist · progress bar
/// · playback controls (Shuffle, Previous, Play/Pause, Next, Repeat).
class PlayerCard extends StatefulWidget {
  const PlayerCard({super.key});

  @override
  State<PlayerCard> createState() => _PlayerCardState();
}

class _PlayerCardState extends State<PlayerCard>
    with SingleTickerProviderStateMixin {
  bool _isPlaying = true;
  bool _isShuffle = false;
  bool _isRepeat = false;
  bool _isLiked = false;
  double _progress = 0.22; // 0.0 – 1.0 mock progress

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
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E1E2E) : colorScheme.surface;

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
          // ── Album Art with glow ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _AlbumArtGlow(
              pulseAnim: _pulseAnim,
              colorScheme: colorScheme,
              isDark: isDark,
            ),
          ),

          // ── Track info + Like ───────────────────────────────────────────
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
                        mockNowPlaying.title,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        mockNowPlaying.artist,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                // Like button
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

          // ── Progress bar ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _ProgressBar(
              progress: _progress,
              primaryColor: colorScheme.primary,
              onChanged: (v) => setState(() => _progress = v),
            ),
          ),

          // ── Playback Controls ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: _PlaybackControls(
              isPlaying: _isPlaying,
              isShuffle: _isShuffle,
              isRepeat: _isRepeat,
              colorScheme: colorScheme,
              onPlayPause: () => setState(() => _isPlaying = !_isPlaying),
              onShuffle: () => setState(() => _isShuffle = !_isShuffle),
              onRepeat: () => setState(() => _isRepeat = !_isRepeat),
              onPrevious: () {}, // Stub – delegation hook
              onNext: () {}, // Stub – delegation hook
            ),
          ),
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
  });

  final Animation<double> pulseAnim;
  final ColorScheme colorScheme;
  final bool isDark;

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
          child: _MockAlbumArt(primaryColor: colorScheme.primary),
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
              const Color(0xFF00BCD4).withValues(alpha: 0.3),
              const Color(0xFF006080).withValues(alpha: 0.1),
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
    required this.onChanged,
  });

  final double progress;
  final Color primaryColor;
  final ValueChanged<double> onChanged;

  String _formatTime(double ratio) {
    const totalSeconds = 210; // 3:30 mock duration
    final elapsed = (ratio * totalSeconds).round();
    final m = elapsed ~/ 60;
    final s = elapsed % 60;
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
            thumbColor: primaryColor,
            overlayColor: primaryColor.withValues(alpha: 0.15),
          ),
          child: Slider(
            value: progress,
            onChanged: onChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatTime(progress),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
              Text(
                mockNowPlaying.duration,
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
