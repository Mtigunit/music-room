import 'package:flutter/material.dart';

class GenreSelectionGrid extends StatelessWidget {
  const GenreSelectionGrid({
    required this.genres,
    required this.selectedGenres,
    required this.onGenreTapped,
    this.maxSelection = 3,
    this.spacing = 12,
    this.runSpacing = 12,
    super.key,
  });

  final List<String> genres;
  final List<String> selectedGenres;
  final ValueChanged<String> onGenreTapped;
  final int maxSelection;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: genres
          .map((genre) {
            final isSelected = selectedGenres.contains(genre);
            final isLimitReached = selectedGenres.length >= maxSelection;
            final isDisabled = isLimitReached && !isSelected;

            return Opacity(
              opacity: isDisabled ? 0.45 : 1,
              child: ChoiceChip(
                label: Text(genre),
                selected: isSelected,
                showCheckmark: false,
                onSelected: isDisabled ? null : (_) => onGenreTapped(genre),
                labelStyle: TextStyle(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
                selectedColor: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.surface,
                elevation: isSelected ? 4 : 0,
                shadowColor: theme.colorScheme.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: isSelected
                        ? Colors.transparent
                        : theme.colorScheme.onSurface.withValues(alpha: 0.1),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}
