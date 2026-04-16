import 'dart:async';

import 'package:flutter/material.dart';

enum AppSnackbarType { info, success, error }

class AppSnackbar {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _show(
      context,
      message,
      type: AppSnackbarType.info,
      duration: duration,
    );
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _show(
      context,
      message,
      type: AppSnackbarType.success,
      duration: duration,
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    _show(
      context,
      message,
      type: AppSnackbarType.error,
      duration: duration,
    );
  }

  static void _show(
    BuildContext context,
    String message, {
    required AppSnackbarType type,
    required Duration duration,
  }) {
    _dismissCurrent();

    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    if (overlayState == null) {
      return;
    }

    final mediaQuery = MediaQuery.maybeOf(context);
    final topPadding = (mediaQuery?.padding.top ?? 0) + 12;

    _currentEntry = OverlayEntry(
      builder: (_) => Positioned(
        top: topPadding,
        left: 16,
        right: 16,
        child: _AppSnackbarCard(
          message: message,
          type: type,
        ),
      ),
    );

    overlayState.insert(_currentEntry!);
    _dismissTimer = Timer(duration, _dismissCurrent);
  }

  static void _dismissCurrent() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _AppSnackbarCard extends StatelessWidget {
  const _AppSnackbarCard({
    required this.message,
    required this.type,
  });

  final String message;
  final AppSnackbarType type;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsForType(type);

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(colors.icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _SnackbarColors _colorsForType(AppSnackbarType type) {
    switch (type) {
      case AppSnackbarType.info:
        return const _SnackbarColors(
          background: Color(0xFF2563EB),
          icon: Icons.info_outline,
        );
      case AppSnackbarType.success:
        return const _SnackbarColors(
          background: Color(0xFF16A34A),
          icon: Icons.check_circle_outline,
        );
      case AppSnackbarType.error:
        return const _SnackbarColors(
          background: Color(0xFFDC2626),
          icon: Icons.error_outline,
        );
    }
  }
}

class _SnackbarColors {
  const _SnackbarColors({
    required this.background,
    required this.icon,
  });

  final Color background;
  final IconData icon;
}
