import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/genre_selection_grid.dart';
import 'package:music_room/core/widgets/responsive_layout.dart';
import 'package:music_room/features/events/domain/entities/event_tag.dart';

class Step2Genre extends StatelessWidget {
  const Step2Genre({
    required this.selectedGenres,
    required this.onGenresChanged,
    required this.canContinue,
    required this.onNext,
    this.errorText,
    super.key,
  });
  final List<EventTag> selectedGenres;
  final ValueChanged<List<EventTag>> onGenresChanged;
  final bool canContinue;
  final String? errorText;
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
    final width = MediaQuery.sizeOf(context).width;
    final size = ResponsiveLayout.resolveSize(width);
    final isCompact = size == ScreenSize.compact;
    final horizontalPadding = isCompact ? 16.0 : 24.0;
    final sectionGap = isCompact ? 20.0 : 24.0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
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
          SizedBox(height: sectionGap),
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
          SizedBox(height: isCompact ? 24 : 32),
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
          if (errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          SizedBox(height: isCompact ? 24 : 32),
          ElevatedButton(
            onPressed: canContinue ? onNext : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: EdgeInsets.symmetric(vertical: isCompact ? 14 : 16),
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
          SizedBox(height: isCompact ? 24 : 32),
        ],
      ),
    );
  }
}
