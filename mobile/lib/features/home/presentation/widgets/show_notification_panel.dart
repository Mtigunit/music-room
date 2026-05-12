import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/responsive_layout.dart';
import 'package:music_room/features/home/presentation/widgets/notification_modal.dart';

/// Shows the notification UI in a viewport-appropriate container.
///
/// On **mobile and tablet** (width < 1024px) the [NotificationModal] is
/// presented as a [showModalBottomSheet] — the existing mobile pattern.
///
/// On **desktop** (width ≥ 1024px) it is presented as a right-aligned
/// side panel overlay (~400px wide, full height) using [showDialog],
/// mimicking the drawer pattern common in desktop web apps.
///
/// **Parameters:**
/// - [context] — the [BuildContext] used to measure screen width and
///   display the modal.
///
/// **Returns** a [Future<void>] that completes when the panel is dismissed.
Future<void> showNotificationPanel({
  required BuildContext context,
}) {
  final width = MediaQuery.of(context).size.width;
  final isDesktop = width >= ResponsiveLayout.expandedBreakpoint;

  if (isDesktop) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close Notifications',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: _DesktopNotificationPanel(
              onClose: () => Navigator.of(context, rootNavigator: true).pop(),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position:
              Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
              ),
          child: child,
        );
      },
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    useSafeArea: true,
    barrierColor: Colors.black.withValues(alpha: 0.8),
    backgroundColor: Colors.transparent,
    builder: (_) => const NotificationModal(),
  );
}

/// Desktop-only right-aligned notification side panel.
/// Full-height, constrained to 400px width, with its own close button
/// replacing the drag handle.
class _DesktopNotificationPanel extends StatelessWidget {
  const _DesktopNotificationPanel({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      width: 400,
      height: screenHeight,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          left: BorderSide(
            color: colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: NotificationModal(
        isPanel: true,
        onClose: onClose,
      ),
    );
  }
}
