import 'package:flutter/material.dart';

class ImportPlaylistModal extends StatefulWidget {
  const ImportPlaylistModal({super.key});

  @override
  State<ImportPlaylistModal> createState() => _ImportPlaylistModalState();
}

class _ImportPlaylistModalState extends State<ImportPlaylistModal> {
  String _searchQuery = '';

  final List<Map<String, dynamic>> _mockPlaylists = [
    {
      'name': 'Late Night Driving',
      'tags': <String>['electronic', 'chill', 'synthwave'],
      'trackCount': 42,
    },
    {
      'name': 'Summer Techno',
      'tags': <String>['techno', 'dance', 'upbeat'],
      'trackCount': 108,
    },
    {
      'name': 'Moroccan Hits',
      'tags': <String>['pop', 'arabic', 'trending'],
      'trackCount': 25,
    },
    {
      'name': 'Gym Motivation',
      'tags': <String>['workout', 'hardstyle', 'bass'],
      'trackCount': 60,
    },
    {
      'name': 'Lo-fi Study',
      'tags': <String>['lo-fi', 'study', 'relax'],
      'trackCount': 200,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filteredPlaylists = _mockPlaylists.where((playlist) {
      final query = _searchQuery.toLowerCase();
      if (query.isEmpty) return true;
      final nameMatches = (playlist['name'] as String).toLowerCase().contains(
        query,
      );
      final tagsMatch = (playlist['tags'] as List<String>).any(
        (tag) => tag.toLowerCase().contains(query),
      );
      return nameMatches || tagsMatch;
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Import Playlist',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search playlists or tags...',
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
              prefixIcon: Icon(
                Icons.search,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: filteredPlaylists.isEmpty
                ? Center(
                    child: Text(
                      'No playlists found.',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: filteredPlaylists.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final pl = filteredPlaylists[index];
                      final name = pl['name'] as String;
                      final tags = (pl['tags'] as List<String>).join(', ');
                      final count = pl['trackCount'] as int;

                      return ListTile(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Importing $name...')),
                          );
                          Navigator.of(context).pop();
                        },
                        leading: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.queue_music,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '$count tracks • $tags',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                            fontSize: 13,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
