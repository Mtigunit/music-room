import 'package:flutter/material.dart';

class HorizontalFilterList extends StatelessWidget {
  const HorizontalFilterList({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
    this.itemPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.listPadding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final EdgeInsetsGeometry itemPadding;
  final EdgeInsetsGeometry listPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: listPadding,
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = index == selectedIndex;
          return ChoiceChip(
            label: Text(items[index]),
            selected: isSelected,
            onSelected: (_) => onSelected(index),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            backgroundColor: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3),
            selectedColor: theme.colorScheme.primary,
            labelStyle: TextStyle(
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          );
        },
      ),
    );
  }
}
