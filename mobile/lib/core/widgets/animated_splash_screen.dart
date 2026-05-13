// ignore_for_file: sort_constructors_first, discarded_futures,
// ignore_for_file: inference_failure_on_instance_creation, unawaited_futures,
// ignore_for_file: avoid_redundant_argument_values, prefer_int_literals,
// ignore_for_file: deprecated_member_use, cascade_invocations

import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/app_icon_painter.dart';

/// A polished animated splash screen featuring the Music Room app icon.
///
/// Displays a coordinated sequence of animations:
/// - Icon path draw-in effect (1.8s with easeInOutCubic)
/// - Glow fade-in overlay (600ms)
/// - Background radial ripple (2.4s)
/// - Exit scale + fade (600ms)
///
/// Calls [onComplete] when all animations finish and the screen exits.
class AnimatedSplashScreen extends StatefulWidget {
  /// Callback when splash animation sequence completes.
  final VoidCallback onComplete;

  const AnimatedSplashScreen({
    required this.onComplete,
    super.key,
  });

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with TickerProviderStateMixin {
  // --- Draw-in animation (0 → 1) ---
  late final AnimationController _drawController;
  late final Animation<double> _drawProgress;

  // --- Glow / opacity fade-in after draw ---
  late final AnimationController _glowController;
  late final Animation<double> _glowOpacity;

  // --- Exit: scale + fade out ---
  late final AnimationController _exitController;
  late final Animation<double> _exitScale;
  late final Animation<double> _exitOpacity;

  // --- Background ripple ---
  late final AnimationController _bgController;
  late final Animation<double> _bgScale;

  bool _completed = false;

  @override
  void initState() {
    super.initState();

    // 1. Draw-in: 1.8s with easeInOutCubic
    _drawController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _drawProgress = CurvedAnimation(
      parent: _drawController,
      curve: Curves.easeInOutCubic,
    );

    // 2. Glow fades in during the last third of the draw
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _glowOpacity = CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeOut,
    );

    // 3. Background radial ripple
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _bgScale = CurvedAnimation(
      parent: _bgController,
      curve: Curves.easeOutExpo,
    );

    // 4. Exit animation
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _exitScale = Tween<double>(begin: 1, end: 1.12).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeIn),
    );
    _exitOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeIn),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    // Small delay before starting
    await Future.delayed(const Duration(milliseconds: 200));

    // Fire bg + draw simultaneously
    _bgController.forward();
    _drawController.forward();

    // Glow kicks in at 70% of draw duration
    await Future.delayed(const Duration(milliseconds: 1260));
    _glowController.forward();

    // Hold for a beat after everything settles
    await Future.delayed(const Duration(milliseconds: 700));

    // Exit
    _exitController.forward();
    await Future.delayed(const Duration(milliseconds: 580));

    if (mounted && !_completed) {
      _completed = true;
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _drawController.dispose();
    _glowController.dispose();
    _bgController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final palette = _SplashPalette.fromTheme(Theme.of(context));

    return Scaffold(
      backgroundColor: palette.background,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _drawProgress,
          _glowOpacity,
          _bgScale,
          _exitOpacity,
          _exitScale,
        ]),
        builder: (context, _) {
          return FadeTransition(
            opacity: _exitOpacity,
            child: ScaleTransition(
              scale: _exitScale,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Background radial gradient that grows ──────────────
                  _buildBackground(size),

                  // ── Centered icon with draw animation ──────────────────
                  Center(
                    child: CustomPaint(
                      size: Size.square(size.shortestSide * 0.4),
                      painter: AppIconPainter(
                        progress: _drawProgress.value,
                        glowIntensity: _glowOpacity.value,
                        primaryColor: palette.primary,
                        glowColor: palette.glow,
                        sparkColor: palette.spark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBackground(Size size) {
    final palette = _SplashPalette.fromTheme(Theme.of(context));

    return CustomPaint(
      size: size,
      painter: _BackgroundRipplePainter(
        scale: _bgScale.value,
        palette: palette,
      ),
    );
  }
}

class _SplashPalette {
  final Color background;
  final Color primary;
  final Color glow;
  final Color spark;

  const _SplashPalette({
    required this.background,
    required this.primary,
    required this.glow,
    required this.spark,
  });

  factory _SplashPalette.fromTheme(ThemeData theme) {
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return _SplashPalette(
      background: scheme.surface,
      primary: scheme.primary,
      glow: isDark ? const Color(0xFFD8B4FE) : const Color(0xFF8B5CF6),
      spark: isDark ? Colors.white : scheme.primary,
    );
  }
}

/// Paints an expanding radial gradient background ripple effect.
class _BackgroundRipplePainter extends CustomPainter {
  final double scale;
  final _SplashPalette palette;

  _BackgroundRipplePainter({
    required this.scale,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width > size.height ? size.width : size.height;

    // Inner: dark background
    canvas.drawCircle(
      center,
      maxRadius * scale * 0.6,
      Paint()
        ..color = palette.background
        ..style = PaintingStyle.fill,
    );

    // Middle: gradient ring
    final radius = maxRadius * scale * 1.2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [
            palette.primary.withOpacity(0.15 * (1 - scale)),
            palette.background,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill,
    );

    // Outer: fade to background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..color = palette.background
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_BackgroundRipplePainter oldDelegate) =>
      oldDelegate.scale != scale ||
      oldDelegate.palette.background != palette.background ||
      oldDelegate.palette.primary != palette.primary ||
      oldDelegate.palette.glow != palette.glow ||
      oldDelegate.palette.spark != palette.spark;
}
