import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/app_button.dart';

enum SocialProvider { google }

class SocialLoginButton extends StatelessWidget {
  const SocialLoginButton({
    required this.provider,
    required this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    super.key,
  });

  final SocialProvider provider;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isEnabled;

  String get _label => 'Continue with Google';

  Widget get _icon => Image.asset(
    'assets/images/google_logo.png',
    width: 22,
    height: 22,
  );

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final disabledColor = isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;
    final borderColor = isEnabled
        ? (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!)
        : disabledColor;
    final textColor = isEnabled
        ? (isDarkMode ? Colors.white : Colors.black87)
        : Colors.grey[600];
    final iconOpacity = isEnabled ? 1.0 : 0.5;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: AppButton(
        variant: AppButtonVariant.outlined,
        onPressed: isEnabled ? onPressed : null,
        isLoading: isLoading,
        borderSide: BorderSide(
          color: borderColor,
        ),
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.6,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Opacity(
                opacity: iconOpacity,
                child: _icon,
              ),
              const SizedBox(width: 12),
              Text(
                _label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
