import 'package:flutter/material.dart';

class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: colorScheme.onSurface.withValues(alpha: 0.4),
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            'Search rooms, tracks, artists...',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.4),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
