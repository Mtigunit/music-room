import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/app_brand_icon.dart';
import 'package:music_room/features/events/data/models/track_model.dart';

enum TrackAddState { idle, loading, success }

/// A unified list tile used inside the DynamicSearchBottomSheet for track
/// search results.
/// Includes an inline 3-state trailing button (Idle -> Loading -> Success).
class TrackSearchListTile extends StatefulWidget {
  const TrackSearchListTile({
    required this.track,
    required this.onAddTapped,
    this.isAlreadyAdded = false,
    super.key,
  });

  final TrackModel track;
  final Future<void> Function(TrackModel) onAddTapped;
  final bool isAlreadyAdded;

  @override
  State<TrackSearchListTile> createState() => _TrackSearchListTileState();
}

class _TrackSearchListTileState extends State<TrackSearchListTile> {
  late TrackAddState _state;

  @override
  void initState() {
    super.initState();
    _state = widget.isAlreadyAdded ? TrackAddState.success : TrackAddState.idle;
  }

  @override
  void didUpdateWidget(TrackSearchListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAlreadyAdded != oldWidget.isAlreadyAdded) {
      _state = widget.isAlreadyAdded
          ? TrackAddState.success
          : TrackAddState.idle;
    }
  }

  Future<void> _handleAdd() async {
    if (_state != TrackAddState.idle) return;

    setState(() {
      _state = TrackAddState.loading;
    });

    try {
      await widget.onAddTapped(widget.track);
      if (mounted) {
        setState(() {
          _state = TrackAddState.success;
        });
      }
    } on Object catch (_) {
      // Revert to idle on error so user can try again
      if (mounted) {
        setState(() {
          _state = TrackAddState.idle;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final rowBg = isDark
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
            child: widget.track.thumbnailUrl.isNotEmpty
                ? Image.network(
                    widget.track.thumbnailUrl,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => _ThumbnailFallback(
                      colorScheme: colorScheme,
                    ),
                  )
                : _ThumbnailFallback(colorScheme: colorScheme),
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
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Trailing widget (3 states)
          _buildTrailingAction(colorScheme),
        ],
      ),
    );
  }

  Widget _buildTrailingAction(ColorScheme colorScheme) {
    switch (_state) {
      case TrackAddState.loading:
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.primary,
          ),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.onPrimary,
              ),
            ),
          ),
        );

      case TrackAddState.success:
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.primary,
          ),
          child: Icon(
            Icons.check,
            color: colorScheme.onPrimary,
            size: 20,
          ),
        );

      case TrackAddState.idle:
        return Semantics(
          button: true,
          label: 'Add to queue',
          child: GestureDetector(
            onTap: _handleAdd,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.onSurface.withValues(alpha: 0.1),
              ),
              child: Icon(
                Icons.add,
                size: 20,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        );
    }
  }
}

class _ThumbnailFallback extends StatelessWidget {
  const _ThumbnailFallback({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      color: colorScheme.primary.withValues(alpha: 0.2),
      child: const Center(child: AppBrandIcon()),
    );
  }
}
