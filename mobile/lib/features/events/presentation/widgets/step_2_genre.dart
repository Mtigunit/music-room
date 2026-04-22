import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/genre_selection_grid.dart';
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
                GenreSelectionGrid(
                  genres: availableGenres
                      .map((tag) => tag.label)
                      .toList(growable: false),
                  selectedGenres: selectedGenres
                      .map((tag) => tag.label)
                      .toList(growable: false),
                  onGenreTapped: (label) {
                    final genre = availableGenres.firstWhere(
                      (tag) => tag.label == label,
                    );
                    _toggleGenre(genre);
                  },
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
