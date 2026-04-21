import 'package:flutter/material.dart';
import 'package:music_room/features/events/domain/entities/event_tag.dart';

class Step2Genre extends StatelessWidget {
  const Step2Genre({
    required this.selectedGenres,
    required this.onGenresChanged,
    required this.onNext,
    super.key,
  });
  final List<EventTag> selectedGenres;
  final ValueChanged<List<EventTag>> onGenresChanged;
  final VoidCallback onNext;

  static const List<EventTag> availableGenres = EventTag.values;

  void _toggleGenre(EventTag genre) {
    final newlySelected = List<EventTag>.from(selectedGenres);
    if (newlySelected.contains(genre)) {
      newlySelected.remove(genre);
      onGenresChanged(newlySelected);
      return;
    }

    if (newlySelected.length >= 3) {
      return;
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
                  'Pick up to 3 tags that define your event vibe.',
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
                    final isLimitReached = selectedGenres.length >= 3;
                    final isDisabled = isLimitReached && !isSelected;

                    return Opacity(
                      opacity: isDisabled ? 0.45 : 1,
                      child: ChoiceChip(
                        label: Text(genre.label),
                        selected: isSelected,
                        showCheckmark: false,
                        onSelected: isDisabled
                            ? null
                            : (_) => _toggleGenre(genre),
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
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                if (selectedGenres.isNotEmpty)
                  Text(
                    '${selectedGenres.length}/3 tags selected',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (selectedGenres.length >= 3) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Maximum reached. Deselect one tag to choose another.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
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
