import 'package:flutter/material.dart';

enum SocialProvider { google, facebook }

class SocialLoginButton extends StatelessWidget {
  const SocialLoginButton({
    required this.provider,
    required this.onPressed,
    super.key,
  });

  final SocialProvider provider;
  final VoidCallback onPressed;

  String get _label {
    switch (provider) {
      case SocialProvider.google:
        return 'Continue with Google';
      case SocialProvider.facebook:
        return 'Continue with Facebook';
    }
  }

  Widget get _icon {
    switch (provider) {
      case SocialProvider.google:
        return Image.asset(
          'assets/images/google_logo.png',
          width: 22,
          height: 22,
        );
      case SocialProvider.facebook:
        return const Icon(
          Icons.facebook,
          color: Color(0xFF1877F2),
          size: 24,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _icon,
            const SizedBox(width: 12),
            Text(
              _label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
