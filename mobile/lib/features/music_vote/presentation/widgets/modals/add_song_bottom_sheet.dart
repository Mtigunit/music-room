import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/app_back_button.dart';
import 'package:music_room/features/music_vote/presentation/widgets/mock_data.dart';

/// "Add Song" search bottom sheet.
///
/// Shows a search field and a mock list of tracks the user can suggest.
class AddSongBottomSheet extends StatefulWidget {
  const AddSongBottomSheet({super.key});

  @override
  State<AddSongBottomSheet> createState() => _AddSongBottomSheetState();
}

class _AddSongBottomSheetState extends State<AddSongBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  List<MockTrack> get _filtered {
    if (_query.isEmpty) return mockSearchTracks;
    final q = _query.toLowerCase();
    return mockSearchTracks
        .where(
          (t) =>
              t.title.toLowerCase().contains(q) ||
              t.artist.toLowerCase().contains(q) ||
              t.album.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sheetBg = isDark ? const Color(0xFF151520) : colorScheme.surface;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Drag handle ──────────────────────────────────────────────
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Header ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    AppBackButton(
                      padding: EdgeInsets.zero,
                      iconSize: 20,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Add a Song',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                        Text(
                          'Search and add to the room',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Search field ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SearchField(
                  controller: _searchController,
                  isDark: isDark,
                  colorScheme: colorScheme,
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(height: 16),

              // ── Track list ───────────────────────────────────────────────
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, separator) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final track = _filtered[index];
                    return _SearchTrackItem(
                      track: track,
                      colorScheme: colorScheme,
                      isDark: isDark,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Reusable search field
// ────────────────────────────────────────────────────────────────────────────

class SearchField extends StatelessWidget {
  const SearchField({
    required this.controller,
    required this.isDark,
    required this.colorScheme,
    required this.onChanged,
    super.key,
    this.hint = 'Song, artist, or album...',
  });

  final TextEditingController controller;
  final bool isDark;
  final ColorScheme colorScheme;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final fieldBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);

    return Container(
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Icon(
              Icons.search,
              size: 20,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.35),
                  fontSize: 15,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Single search result row
// ────────────────────────────────────────────────────────────────────────────

class _SearchTrackItem extends StatefulWidget {
  const _SearchTrackItem({
    required this.track,
    required this.colorScheme,
    required this.isDark,
  });

  final MockTrack track;
  final ColorScheme colorScheme;
  final bool isDark;

  @override
  State<_SearchTrackItem> createState() => _SearchTrackItemState();
}

class _SearchTrackItemState extends State<_SearchTrackItem> {
  bool _added = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rowBg = widget.isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.02);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 52,
              height: 52,
              color: Color(widget.track.colorHex),
              child: const Icon(
                Icons.music_note,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Track info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.track.title,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.track.artist,
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: widget.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  widget.track.album,
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: widget.colorScheme.primary.withValues(alpha: 0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          Semantics(
            button: true,
            label: _added ? 'Remove from queue' : 'Add to queue',
            child: GestureDetector(
              onTap: () {
                setState(() => _added = !_added);
                if (kDebugMode) {
                  debugPrint('Added to queue: ${widget.track.title}');
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _added
                      ? widget.colorScheme.primary
                      : widget.colorScheme.onSurface.withValues(alpha: 0.1),
                ),
                child: Icon(
                  _added ? Icons.check : Icons.add,
                  size: 18,
                  color: _added
                      ? Colors.white
                      : widget.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
