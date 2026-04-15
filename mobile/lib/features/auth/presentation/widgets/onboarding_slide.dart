import 'package:flutter/material.dart';

class OnboardingSlide extends StatelessWidget {
  final String imagePath;
  final String title;
  final String subtitle;
  final List<Widget> chips;
  final Widget indicator;

  const OnboardingSlide({
    super.key,
    required this.imagePath,
    required this.title,
    required this.subtitle,
    required this.chips,
    required this.indicator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.0),
            child: Image.asset(
              imagePath,
              cacheHeight: 800,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ),
          const SizedBox(height: 24.0),
          indicator,
          const SizedBox(height: 24.0),
          Text(
            title,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.1,
                ),
          ),
          const SizedBox(height: 16.0),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 24.0),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: chips,
          ),
        ],
    );
  }
}
