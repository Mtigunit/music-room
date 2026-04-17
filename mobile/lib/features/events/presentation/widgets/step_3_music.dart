import 'package:flutter/material.dart';

class Step3Music extends StatelessWidget {
  const Step3Music({
    required this.selectedTracks,
    required this.onTracksChanged,
    required this.onNext,
    super.key,
  });
  final List<String> selectedTracks;
  final ValueChanged<List<String>> onTracksChanged;
  final VoidCallback onNext;

  void _addMockTrack() {
    final updatedTracks = List<String>.from(selectedTracks)
      ..add('Dummy Track ${selectedTracks.length + 1} - Dummy Artist');
    onTracksChanged(updatedTracks);
  }

  void _removeTrack(int index) {
    final updatedTracks = List<String>.from(selectedTracks)..removeAt(index);
    onTracksChanged(updatedTracks);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCount = selectedTracks.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Set up the initial music queue.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search for tracks to add...',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.35,
                      ),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.1,
                        ),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: theme.colorScheme.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      final updated = List<String>.from(selectedTracks)
                        ..add(value);
                      onTracksChanged(updated);
                    }
                  },
                ),
                const SizedBox(height: 16),

                OutlinedButton.icon(
                  onPressed: _addMockTrack,
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('Import Existing Playlist'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.55),
                    ),
                    foregroundColor: theme.colorScheme.primary,
                    textStyle: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'SELECTED TRACKS ($selectedCount)',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: selectedTracks.isEmpty
                      ? Center(
                          child: Text(
                            'No tracks selected yet.',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: selectedTracks.length,
                          itemBuilder: (context, index) {
                            final parts = selectedTracks[index].split(' - ');
                            final trackTitle = parts.first;
                            final artistName = parts.length > 1
                                ? parts.sublist(1).join(' - ')
                                : 'Dummy Artist';

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              minVerticalPadding: 8,
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.music_note,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              title: Text(
                                trackTitle,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                artistName,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => _removeTrack(index),
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                            );
                          },
                        ),
                ),
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
