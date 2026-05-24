import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/app_button.dart';

enum ConfirmationDialogVariant {
  neutral,
  destructive,
}

Future<bool?> showAppConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  IconData icon = Icons.help_outline_rounded,
  ConfirmationDialogVariant variant = ConfirmationDialogVariant.neutral,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
}) {
  if (!context.mounted) {
    return Future<bool?>.value(false);
  }

  final scrimColor = Theme.of(context).colorScheme.scrim.withValues(alpha: 0.5);

  return showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    useRootNavigator: useRootNavigator,
    barrierColor: scrimColor,
    builder: (_) {
      return AppConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        icon: icon,
        variant: variant,
      );
    },
  );
}

class AppConfirmationDialog extends StatelessWidget {
  const AppConfirmationDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    super.key,
    this.cancelLabel = 'Cancel',
    this.icon = Icons.help_outline_rounded,
    this.variant = ConfirmationDialogVariant.neutral,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final IconData icon;
  final ConfirmationDialogVariant variant;

  bool get _isDestructive => variant == ConfirmationDialogVariant.destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final accentColor = _isDestructive
        ? colorScheme.error
        : colorScheme.primary;
    final accentContainerColor = _isDestructive
        ? colorScheme.errorContainer
        : colorScheme.primaryContainer;

    final screenSize = MediaQuery.sizeOf(context);
    final horizontalInset = screenSize.width < 400 ? 16.0 : 24.0;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.primary.withValues(alpha: 0.08),
      elevation: 8,
      constraints: const BoxConstraints(maxWidth: 460),
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 20, 16, 16),

      // ── Title ──────────────────────────────────────────────────────────
      title: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: accentContainerColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 24,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),

      // ── Body ───────────────────────────────────────────────────────────
      content: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.72),
          height: 1.45,
        ),
      ),

      // ── Actions ────────────────────────────────────────────────────────
      // AlertDialog renders each entry in `actions` as a separate widget
      // in its internal Row (via ButtonBar / OverflowBar). Putting a single
      // Wrap or Column here fights that internal layout. Instead, supply the
      // two buttons as separate list entries and let `actionsAlignment` pin
      // them to the trailing edge — they will always sit side-by-side.
      actionsAlignment: MainAxisAlignment.spaceBetween,
      // actionsOverflowAlignment controls stacking order when the buttons
      // genuinely cannot fit (e.g. very long translated labels). Setting it
      // to end keeps the primary action on top in that rare case.
      actionsOverflowAlignment: OverflowBarAlignment.end,
      // OverflowBar (used internally by AlertDialog for actions) stacks
      // children vertically only when they truly overflow. The spacing
      // between buttons in the horizontal layout is set via ButtonBar theme
      // or directly with the overflowSpacing below.
      actionsOverflowButtonSpacing: 8,
      actions: [
        Row(
          children: [
            Expanded(
              child: AppButton(
                onPressed: () => Navigator.of(context).pop(false),
                variant: AppButtonVariant.outlined,
                label: cancelLabel,
                padding: const EdgeInsets.symmetric(vertical: 12),
                borderSide: BorderSide(color: colorScheme.outlineVariant),
                foregroundColor: colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8), // spacing between buttons
            Expanded(
              child: AppButton(
                onPressed: () => Navigator.of(context).pop(true),
                label: confirmLabel,
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: accentColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
