import 'package:flutter/material.dart';

class PlaylistCollageImage extends StatelessWidget {
  const PlaylistCollageImage({
    required this.thumbnailUrl,
    required this.collageImageUrls,
    this.size = 72,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    super.key,
  });

  final String? thumbnailUrl;
  final List<String> collageImageUrls;
  final double size;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // 1. If custom thumbnail is provided, show it
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return _buildSingleImage(thumbnailUrl!, colorScheme);
    }

    // 2. If no thumbnail but we have collage images, build the collage
    if (collageImageUrls.isNotEmpty) {
      if (collageImageUrls.length >= 4) {
        return _buildCollage(collageImageUrls.take(4).toList(), colorScheme);
      }
      // If 1-3 images, just show the first one as a single image
      return _buildSingleImage(collageImageUrls.first, colorScheme);
    }

    // 3. Fallback to placeholder icon
    return _buildPlaceholder(colorScheme);
  }

  Widget _buildSingleImage(String url, ColorScheme colorScheme) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.5),
        ),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) =>
              _buildPlaceholder(colorScheme),
        ),
      ),
    );
  }

  Widget _buildCollage(List<String> urls, ColorScheme colorScheme) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildGridItem(urls[0], colorScheme)),
                  Expanded(child: _buildGridItem(urls[1], colorScheme)),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildGridItem(urls[2], colorScheme)),
                  Expanded(child: _buildGridItem(urls[3], colorScheme)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridItem(String url, ColorScheme colorScheme) {
    final placeholderColor = colorScheme.onSurface.withValues(alpha: 0.08);

    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return ColoredBox(
          color: placeholderColor,
          child: Center(
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
                color: colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => ColoredBox(
        color: placeholderColor,
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 14,
          color: colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: borderRadius,
      ),
      child: Icon(
        Icons.queue_music_rounded,
        color: colorScheme.primary,
        size: size * 0.4,
      ),
    );
  }
}
