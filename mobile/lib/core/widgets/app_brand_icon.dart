import 'package:flutter/widgets.dart';

/// Small wrapper to render the app's branded icon from assets.
/// Use this in place of generic music icons to keep branding consistent.
class AppBrandIcon extends StatelessWidget {
  const AppBrandIcon({
    this.size = 24,
    this.assetPath = 'assets/icon/brand_icon.png',
    this.color,
    super.key,
  });

  final double size;
  final String assetPath;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ImageIcon(
      AssetImage(assetPath),
      size: size,
      color: color ?? const Color(0xFFFFFFFF),
    );
  }
}
