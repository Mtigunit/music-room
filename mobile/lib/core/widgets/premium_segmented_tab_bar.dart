import 'package:flutter/material.dart';

/// A reusable premium segmented [TabBar] surface.
class PremiumSegmentedTabBar extends StatelessWidget {
  const PremiumSegmentedTabBar({
    required this.tabs,
    super.key,
    this.onTap,
    this.margin = const EdgeInsets.only(top: 12),
    this.height = 48,
    this.width,
  });

  final List<Tab> tabs;
  final ValueChanged<int>? onTap;
  final EdgeInsetsGeometry margin;
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        onTap: onTap,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primary,
              colorScheme.primary.withValues(alpha: 0.85),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(
          Colors.transparent,
        ),
        labelColor: Colors.white,
        unselectedLabelColor: colorScheme.onSurface.withValues(alpha: 0.6),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        labelPadding: EdgeInsets.zero,
        tabs: tabs,
      ),
    );
  }
}
