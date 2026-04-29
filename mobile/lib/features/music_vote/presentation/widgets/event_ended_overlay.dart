import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

/// A premium full-screen overlay shown when a Live Event is ended by the host.
///
/// Displays a countdown and then executes [onFinished].
class EventEndedOverlay extends StatefulWidget {
  const EventEndedOverlay({
    required this.onFinished,
    super.key,
  });

  final VoidCallback onFinished;

  @override
  State<EventEndedOverlay> createState() => _EventEndedOverlayState();
}

class _EventEndedOverlayState extends State<EventEndedOverlay> {
  int _secondsRemaining = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        widget.onFinished();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final overlayColor = isDark
        ? Colors.black.withValues(alpha: 0.85)
        : colorScheme.surface.withValues(alpha: 0.9);

    final textColor = colorScheme.onSurface;
    final subtitleColor = colorScheme.onSurface.withValues(alpha: 0.7);
    final containerColor = colorScheme.onSurface.withValues(alpha: 0.05);
    final borderColor = colorScheme.onSurface.withValues(alpha: 0.1);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Blurred background ───────────────────────────────────────────
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: overlayColor,
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated Pulse Icon
                _AnimatedPulseIcon(color: colorScheme.primary),
                const SizedBox(height: 32),

                // Main Title
                Text(
                  'Event Has Ended',
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Subtitle
                Text(
                  'The host has closed the room.',
                  style: textTheme.bodyLarge?.copyWith(
                    color: subtitleColor,
                  ),
                ),
                const SizedBox(height: 48),

                // Countdown indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: borderColor,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          value: _secondsRemaining / 5,
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Redirecting in $_secondsRemaining seconds...',
                        style: textTheme.bodyMedium?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedPulseIcon extends StatefulWidget {
  const _AnimatedPulseIcon({required this.color});
  final Color color;

  @override
  State<_AnimatedPulseIcon> createState() => _AnimatedPulseIconState();
}

class _AnimatedPulseIconState extends State<_AnimatedPulseIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    unawaited(_controller.repeat());

    _scale = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _opacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scale.value,
              child: Opacity(
                opacity: _opacity.value,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: widget.color, width: 4),
                  ),
                ),
              ),
            );
          },
        ),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle_outline,
            size: 48,
            color: widget.color,
          ),
        ),
      ],
    );
  }
}
