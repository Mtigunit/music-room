import 'package:flutter/material.dart';

class HorizontalFilterList extends StatelessWidget {
  const HorizontalFilterList({
    required this.items,
    this.selectedIndex = 0,
    this.onSelected,
    this.height = 40,
    this.itemSpacing = 12,
    this.itemPadding = const EdgeInsets.symmetric(horizontal: 24),
    this.listPadding,
    this.borderRadius = 20,
    this.fontSize = 14,
    this.selectedFontWeight = FontWeight.w600,
    this.unselectedFontWeight = FontWeight.w500,
    super.key,
  });

  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int>? onSelected;
  final double height;
  final double itemSpacing;
  final EdgeInsetsGeometry itemPadding;
  final EdgeInsetsGeometry? listPadding;
  final double borderRadius;
  final double fontSize;
  final FontWeight selectedFontWeight;
  final FontWeight unselectedFontWeight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: height,
      child: ListView.separated(
        clipBehavior: Clip.none,
        padding: listPadding,
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => SizedBox(width: itemSpacing),
        itemBuilder: (context, index) {
          final isSelected = index == selectedIndex;

          return GestureDetector(
            onTap: () => onSelected?.call(index),
            child: Container(
              padding: itemPadding,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(borderRadius),
                border: isSelected
                    ? null
                    : Border.all(
                        color: colorScheme.onSurface.withValues(alpha: 0.1),
                      ),
              ),
              child: Text(
                items[index],
                style: TextStyle(
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: isSelected
                      ? selectedFontWeight
                      : unselectedFontWeight,
                  fontSize: fontSize,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

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
    return HorizontalFilterList(
      items: genres,
      selectedIndex: selectedIndex,
      onSelected: onSelected,
    );
  }
}
