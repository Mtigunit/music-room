import 'package:flutter/material.dart';
import 'package:music_room/core/models/tag_option.dart';
import 'package:music_room/core/utils/tag_genre_normalizer.dart';

class GenreChipGroup extends StatelessWidget {
  const GenreChipGroup({
    required this.selectedGenres,
    required this.onGenresChanged,
    super.key,
  });

  final List<String> selectedGenres;
  final ValueChanged<List<String>> onGenresChanged;

  void _toggleGenre(TagOption<String> tag) {
    final newlySelected = List<String>.from(selectedGenres);
    if (newlySelected.contains(tag.value)) {
      newlySelected.remove(tag.value);
    } else {
      newlySelected.add(tag.value);
    }
    onGenresChanged(newlySelected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: TagGenreNormalizer.allTags.map((tag) {
            final isSelected = selectedGenres.contains(tag.value);
            final displayLabel =
                TagGenreNormalizer.toDisplayLabel(tag) ?? tag.displayLabel;
            return ChoiceChip(
              label: Text(displayLabel),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) => _toggleGenre(tag),
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
            );
          }).toList(),
        ),
        const SizedBox(height: 32),
        if (selectedGenres.isNotEmpty)
          Text(
            '${selectedGenres.length} genres selected',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }
}
