// ignore_for_file: sort_constructors_first, cascade_invocations,
// ignore_for_file: deprecated_member_use, prefer_const_constructors,
// ignore_for_file: prefer_final_locals, omit_local_variable_types

import 'package:flutter/material.dart';

/// Paints the Music Room app icon SVG path with a progressive draw-in effect.
///
/// [progress] 0.0 → 1.0 controls how much of the stroke is visible.
/// [glowIntensity] 0.0 → 1.0 adds a glowing fill once drawn.
class AppIconPainter extends CustomPainter {
  final double progress;
  final double glowIntensity;
  final Color primaryColor;
  final Color glowColor;
  final Color sparkColor;

  AppIconPainter({
    required this.progress,
    required this.glowIntensity,
    required this.primaryColor,
    required this.glowColor,
    required this.sparkColor,
  });

  // Original SVG viewBox dimensions
  static const double _vbW = 1314;
  static const double _vbH = 1065;

  @override
  void paint(Canvas canvas, Size size) {
    // Scale to fit widget size while preserving aspect ratio
    final scaleX = size.width / _vbW;
    final scaleY = size.height / _vbH;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final dx = (size.width - _vbW * scale) / 2;
    final dy = (size.height - _vbH * scale) / 2;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);

    final path = _buildPath();

    // ── 1. Filled shape (fades in with progress) ──────────────────────────
    if (progress > 0.01) {
      final fillOpacity = (progress - 0.3).clamp(0.0, 1.0) / 0.7;
      final fillPaint = Paint()
        ..color = primaryColor.withOpacity(fillOpacity * 0.9)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);
    }

    // ── 2. Glow fill overlay ──────────────────────────────────────────────
    if (glowIntensity > 0) {
      final glowFillPaint = Paint()
        ..shader = const RadialGradient(
          center: Alignment(0.2, -0.1),
          radius: 0.9,
          colors: [
            Color(0xFFB49BFF),
            Color(0xFF7049FF),
          ],
        ).createShader(Rect.fromLTWH(0, 0, _vbW, _vbH))
        ..style = PaintingStyle.fill
        ..blendMode = BlendMode.srcOver;
      canvas.drawPath(
        path,
        glowFillPaint..color = glowColor.withOpacity(glowIntensity * 0.25),
      );
    }

    // ── 3. Animated stroke (draw-in effect) ──────────────────────────────
    if (progress < 1.0 || glowIntensity < 1.0) {
      final strokeOpacity = progress > 0.95
          ? 1.0 - ((progress - 0.95) / 0.05) * glowIntensity
          : 1.0;

      final strokePaint = Paint()
        ..color = glowColor.withOpacity(strokeOpacity.clamp(0, 1))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0 / scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      // PathMetrics trick: draw only [0..progress] of the total length
      final metrics = path.computeMetrics();
      double totalLength = 0;
      for (final m in metrics) {
        totalLength += m.length;
      }

      // Re-iterate to draw partial path
      double drawn = 0;
      for (final metric in path.computeMetrics()) {
        final segEnd = drawn + metric.length;
        final targetLength = totalLength * progress;

        if (drawn >= targetLength) break;

        final endFraction = ((targetLength - drawn) / metric.length).clamp(
          0.0,
          1.0,
        );

        final partial = metric.extractPath(0, metric.length * endFraction);
        canvas.drawPath(partial, strokePaint);

        drawn = segEnd;
      }
    }

    // ── 4. Leading "spark" dot at the draw tip ────────────────────────────
    if (progress > 0.01 && progress < 0.99) {
      _drawLeadingSpark(canvas, path, progress);
    }

    canvas.restore();
  }

  void _drawLeadingSpark(Canvas canvas, Path path, double progress) {
    final metrics = path.computeMetrics().toList();
    double totalLength = 0;
    for (final m in metrics) {
      totalLength += m.length;
    }

    double targetLength = totalLength * progress;
    double walked = 0;

    for (final metric in metrics) {
      if (walked + metric.length >= targetLength) {
        final local = targetLength - walked;
        final tangent = metric.getTangentForOffset(local);
        if (tangent == null) break;

        final sparkPaint = Paint()
          ..color = sparkColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
        canvas.drawCircle(tangent.position, 14, sparkPaint);

        final corePaint = Paint()..color = sparkColor;
        canvas.drawCircle(tangent.position, 5, corePaint);
        break;
      }
      walked += metric.length;
    }
  }

  /// Builds the Flutter [Path] from the SVG d-attribute.
  Path _buildPath() {
    final path = Path();

    path.moveTo(560.831, 1.24834);
    path.cubicTo(543.364, 3.78167, 524.031, 11.515, 509.897, 21.6483);
    path.cubicTo(505.364, 24.8483, 496.831, 32.5817, 490.964, 38.8483);
    path.cubicTo(470.697, 60.4483, 457.764, 88.8483, 452.431, 124.448);
    path.cubicTo(450.697, 136.048, 450.431, 179.648, 450.431, 454.982);
    path.cubicTo(450.431, 803.382, 450.831, 786.182, 442.431, 811.782);
    path.cubicTo(420.031, 880.315, 350.164, 924.048, 278.831, 914.315);
    path.cubicTo(265.764, 912.582, 243.897, 905.382, 230.564, 898.448);
    path.cubicTo(216.964, 891.248, 199.097, 877.782, 189.097, 866.715);
    path.cubicTo(119.897, 791.248, 144.031, 672.848, 237.631, 628.982);
    path.cubicTo(269.897, 613.915, 310.697, 611.782, 346.164, 623.248);
    path.cubicTo(365.097, 629.515, 382.164, 639.648, 402.031, 656.582);
    path.lineTo(408.431, 662.182);
    path.lineTo(408.164, 574.848);
    path.cubicTo(408.031, 503.782, 407.631, 487.248, 406.164, 486.315);
    path.cubicTo(402.831, 484.048, 377.897, 476.848, 363.097, 473.648);
    path.cubicTo(340.031, 468.848, 321.364, 467.382, 290.697, 468.182);
    path.cubicTo(242.431, 469.248, 206.831, 477.915, 165.097, 498.582);
    path.cubicTo(61.0973, 550.182, -3.7027, 658.982, 0.163965, 775.782);
    path.cubicTo(5.23063, 928.582, 126.831, 1053.38, 280.697, 1063.65);
    path.cubicTo(362.831, 1069.25, 446.564, 1038.32, 506.297, 980.448);
    path.cubicTo(556.697, 931.648, 585.897, 873.382, 595.097, 803.115);
    path.cubicTo(596.964, 788.982, 597.231, 757.648, 597.097, 542.448);
    path.cubicTo(597.097, 275.382, 596.831, 287.382, 604.697, 272.848);
    path.cubicTo(606.697, 269.115, 610.697, 264.315, 613.631, 262.315);
    path.cubicTo(633.631, 247.648, 652.564, 264.715, 679.897, 321.782);
    path.cubicTo(698.964, 361.648, 709.631, 391.248, 747.364, 507.782);
    path.cubicTo(793.364, 650.448, 804.831, 679.382, 828.297, 713.782);
    path.cubicTo(860.431, 760.848, 905.364, 782.715, 958.831, 777.115);
    path.cubicTo(990.831, 773.915, 1018.43, 761.515, 1042.96, 739.648);
    path.cubicTo(1069.36, 716.048, 1084.3, 693.915, 1114.16, 634.715);
    path.cubicTo(1126.16, 610.715, 1138.96, 585.648, 1142.7, 579.115);
    path.cubicTo(1181.1, 511.382, 1223.36, 475.115, 1280.56, 460.448);
    path.cubicTo(1287.76, 458.715, 1298.43, 456.715, 1304.03, 456.315);
    path.cubicTo(1309.76, 455.782, 1314.03, 454.848, 1313.63, 454.182);
    path.cubicTo(1312.43, 452.182, 1298.7, 443.915, 1286.03, 437.648);
    path.cubicTo(1251.23, 420.048, 1216.56, 411.915, 1177.76, 411.782);
    path.cubicTo(1103.1, 411.782, 1048.83, 446.182, 1007.23, 520.048);
    path.cubicTo(982.697, 563.782, 976.031, 573.115, 965.497, 579.382);
    path.cubicTo(949.364, 588.848, 931.364, 579.782, 920.564, 556.582);
    path.cubicTo(915.764, 546.315, 906.031, 517.515, 884.431, 450.448);
    path.cubicTo(837.097, 302.982, 820.964, 260.582, 786.297, 191.782);
    path.cubicTo(726.831, 73.6483, 668.964, 12.8483, 605.497, 1.78167);
    path.cubicTo(593.364, -0.351663, 573.231, -0.618329, 560.831, 1.24834);
    path.close();

    return path;
  }

  @override
  bool shouldRepaint(AppIconPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.glowIntensity != glowIntensity ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.sparkColor != sparkColor;
  }
}
