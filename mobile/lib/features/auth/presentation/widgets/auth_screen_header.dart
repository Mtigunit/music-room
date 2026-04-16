import 'package:flutter/material.dart';

class AuthScreenHeader extends StatelessWidget {
  const AuthScreenHeader({
    required this.title,
    required this.subtitle,
    super.key,
    this.titleFontSize = 32,
    this.subtitleTopSpacing = 8,
    this.bottomSpacing = 24,
  });

  final String title;
  final String subtitle;
  final double titleFontSize;
  final double subtitleTopSpacing;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontSize: titleFontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: subtitleTopSpacing),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        SizedBox(height: bottomSpacing),
      ],
    );
  }
}
