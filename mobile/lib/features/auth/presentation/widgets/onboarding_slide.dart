import 'package:flutter/material.dart';

class OnboardingSlide extends StatelessWidget {

  const OnboardingSlide({
    required this.imagePath,
    required this.title,
    required this.subtitle,
    required this.chips,
    required this.indicator,
    super.key,
  });
  final String imagePath;
  final String title;
  final String subtitle;
  final List<Widget> chips;
  final Widget indicator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
              final cacheHeight =
                  constraints.maxHeight.isFinite && constraints.maxHeight > 0
                  ? (constraints.maxHeight * devicePixelRatio).round()
                  : null;
              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  imagePath,
                  cacheHeight: cacheHeight,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        indicator,
        const SizedBox(height: 24),
        Text(
          title,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(
              alpha: 0.6,
            ),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips,
        ),
      ],
    );
  }
}
