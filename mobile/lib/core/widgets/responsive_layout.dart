import 'package:flutter/material.dart';

/// Breakpoint thresholds for responsive layout decisions.
///
/// - [compact]: Phone portrait (< 600px)
/// - [medium]:  Tablet / small laptop (600–1024px)
/// - [expanded]: Desktop browser (> 1024px)
enum ScreenSize { compact, medium, expanded }

/// A [LayoutBuilder]-based widget that resolves the current [ScreenSize]
/// from the available horizontal space and passes it to a builder callback.
///
/// Prefer this over raw [MediaQuery] because it measures the *available*
/// parent constraints, not the device window — making it safe inside
/// nested scrollable or constrained containers.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({required this.builder, super.key});

  /// Builder callback receiving the resolved [ScreenSize].
  final Widget Function(BuildContext context, ScreenSize size) builder;

  /// Breakpoint constants — centralised so every consumer agrees.
  static const double compactBreakpoint = 600;
  static const double expandedBreakpoint = 1024;

  /// Resolve a width value to its [ScreenSize] bucket.
  static ScreenSize resolveSize(double width) {
    if (width >= expandedBreakpoint) return ScreenSize.expanded;
    if (width >= compactBreakpoint) return ScreenSize.medium;
    return ScreenSize.compact;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = resolveSize(constraints.maxWidth);
        return builder(context, size);
      },
    );
  }
}
