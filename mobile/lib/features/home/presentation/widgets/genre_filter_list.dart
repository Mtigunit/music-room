import 'package:flutter/material.dart';

class GenreFilterList extends StatelessWidget {
  const GenreFilterList({
    super.key,
    this.selectedIndex = 0,
    this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int>? onSelected;

  static const List<String> genres = [
    'All',
    'Electronic',
    'Hip Hop',
    'Lo-Fi',
    'Pop',
    'Jazz',
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        itemCount: genres.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final isSelected = index == selectedIndex;
          return GestureDetector(
            onTap: () => onSelected?.call(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: isSelected
                    ? null
                    : Border.all(
                        color: colorScheme.onSurface.withValues(alpha: 0.1),
                      ),
              ),
              child: Text(
                genres[index],
                style: TextStyle(
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
