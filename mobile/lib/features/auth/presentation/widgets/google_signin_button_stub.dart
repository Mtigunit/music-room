import 'package:flutter/material.dart';

class GoogleWebSignInButton extends StatelessWidget {
  const GoogleWebSignInButton({
    required this.onIdToken,
    super.key,
  });

  final Future<void> Function(String idToken) onIdToken;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
