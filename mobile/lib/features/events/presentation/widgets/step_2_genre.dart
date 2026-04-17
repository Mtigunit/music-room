import 'package:flutter/material.dart';

class Step2Genre extends StatelessWidget {
  const Step2Genre({
    required this.selectedGenres,
    required this.onGenresChanged,
    required this.onNext,
    super.key,
  });
  final List<String> selectedGenres;
  final ValueChanged<List<String>> onGenresChanged;
  final VoidCallback onNext;

  static const List<String> availableGenres = [
    'Electronic',
    'Hip Hop',
    'Lo-Fi',
    'House',
    'Indie',
    'Jazz',
    'Pop',
    'R&B',
    'Techno',
    'Ambient',
    'Drum & Bass',
    'Soul',
  ];

  void _toggleGenre(String genre) {
    final newlySelected = List<String>.from(selectedGenres);
    if (newlySelected.contains(genre)) {
      newlySelected.remove(genre);
    } else {
      newlySelected.add(genre);
    }
    onGenresChanged(newlySelected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Pick the genres that define your room's vibe.",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: availableGenres.map((genre) {
                    final isSelected = selectedGenres.contains(genre);
                    return ChoiceChip(
                      label: Text(genre),
                      selected: isSelected,
                      showCheckmark: false,
                      onSelected: (_) => _toggleGenre(genre),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                        fontWeight: FontWeight.w500,
                      ),
                      selectedColor: theme.colorScheme.primary,
                      backgroundColor: theme.colorScheme.surface,
                      elevation: isSelected ? 4 : 0,
                      shadowColor: theme.colorScheme.primary.withValues(
                        alpha: 0.4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(
                          color: isSelected
                              ? Colors.transparent
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.1,
                                ),
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
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
          child: ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: const Text('Continue'),
          ),
        ),
      ],
    );
  }
}
