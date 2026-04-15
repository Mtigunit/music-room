import 'package:flutter/material.dart';

class FeatureChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const FeatureChip({
    super.key,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: colorScheme.secondary,
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18.0,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8.0),
          Text(
            label,
            style: TextStyle(
              fontSize: 13.0,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
