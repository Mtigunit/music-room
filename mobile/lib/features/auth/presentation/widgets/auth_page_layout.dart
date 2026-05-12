import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/responsive_layout.dart';
import 'package:music_room/features/auth/presentation/widgets/auth_brand_panel.dart';

/// A shared layout wrapper for all auth screens (sign-in, sign-up,
/// forgot-password, enter-new-password).
///
/// Behaviour by viewport:
/// - **compact** (< 600px): Full-width with 24px horizontal padding
///   — identical to the current mobile layout.
/// - **medium** (600–1024px): Content centred with a max-width of 480px.
/// - **expanded** (≥ 1024px): Split-panel — gradient brand panel on the
///   left (~45%), auth form on the right (~55%), form capped at 480px.
///
/// Set [showBrandPanel] to `false` for sub-pages (forgot-password,
/// enter-new-password) where the split layout adds visual noise.
class AuthPageLayout extends StatelessWidget {
  const AuthPageLayout({
    required this.child,
    super.key,
    this.showBrandPanel = true,
  });

  /// The form content to render.
  final Widget child;

  /// Whether to show the gradient brand panel on desktop viewports.
  /// Set to `false` for secondary auth pages.
  final bool showBrandPanel;

  /// Max width for the auth form card on non-compact viewports.
  static const double formMaxWidth = 480;

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      builder: (context, size) {
        return switch (size) {
          ScreenSize.compact => _buildCompact(context),
          ScreenSize.medium => _buildMedium(context),
          ScreenSize.expanded => _buildExpanded(context),
        };
      },
    );
  }

  /// Phone: full-width, horizontal padding applied by the child.
  Widget _buildCompact(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: child,
    );
  }

  /// Tablet: centre-constrained card, no brand panel.
  Widget _buildMedium(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: formMaxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: child,
          ),
        ),
      ),
    );
  }

  /// Desktop: optional split-panel with brand panel on left.
  Widget _buildExpanded(BuildContext context) {
    if (!showBrandPanel) {
      // Sub-pages: centred card without the brand panel.
      return _buildMedium(context);
    }

    return Row(
      children: [
        // Left — brand panel (~45%)
        const Expanded(
          flex: 45,
          child: AuthBrandPanel(),
        ),
        // Right — form (~55%)
        Expanded(
          flex: 55,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: formMaxWidth),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
