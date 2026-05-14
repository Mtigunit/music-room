import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/responsive_layout.dart';
import 'package:music_room/features/auth/presentation/widgets/auth_page_layout.dart';
import 'package:music_room/features/auth/presentation/widgets/otp_verification_modal.dart';

/// Displays the OTP verification UI, adapting its container to the viewport.
///
/// On **mobile and tablet** (width < 1024px) the [OtpVerificationModal] is
/// presented inside a [showModalBottomSheet] — the native mobile pattern.
///
/// On **desktop** (width ≥ 1024px) it is presented inside a [showDialog]
/// constrained to 480px, avoiding the awkward full-width bottom sheet that
/// would otherwise span a wide browser window.
///
/// The breakpoint is sourced from [ResponsiveLayout.expandedBreakpoint]
/// (currently 1024px) to stay consistent with other responsive utilities.
///
/// **Parameters:**
/// - [context] — the [BuildContext] used to measure screen width and show
///   the modal. Callers can dismiss the modal via
///   `Navigator.of(context, rootNavigator: true).maybePop()`.
/// - [title] — heading displayed at the top of the OTP card.
/// - [message] — explanatory text shown below the title.
/// - [destination] — optional email or phone number highlighted below
///   [message] (e.g. `'user@example.com'`).
/// - [onConfirm] — callback invoked with the completed OTP string when the
///   user taps the confirm button.
/// - [onResend] — callback invoked when the user requests a new code.
/// - [confirmLabel] — label for the confirm button, defaults to `'Confirm'`.
///
/// **Returns** a [Future<void>] that completes when the modal is dismissed,
/// allowing callers to chain `.whenComplete(...)` for cleanup.
Future<void> showOtpModal({
  required BuildContext context,
  required String title,
  required String message,
  required void Function(String otpCode) onConfirm,
  required VoidCallback onResend,
  String? destination,
  String confirmLabel = 'Confirm',
}) {
  final width = MediaQuery.of(context).size.width;
  final isDesktop = width >= ResponsiveLayout.expandedBreakpoint;

  final modalContent = OtpVerificationModal(
    title: title,
    message: message,
    destination: destination,
    confirmLabel: confirmLabel,
    onConfirm: onConfirm,
    onResend: onResend,
  );

  if (isDesktop) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AuthPageLayout.formMaxWidth,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: modalContent,
            ),
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    enableDrag: false,
    isDismissible: false,
    backgroundColor: Colors.transparent,
    builder: (_) => modalContent,
  );
}
