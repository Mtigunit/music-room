import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/app_button.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.text,
    required this.onPressed,
    super.key,
    this.icon,
  });
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: AppButton(
        onPressed: onPressed,
        label: text,
        trailing: icon != null ? Icon(icon) : null,
        borderRadius: 16,
      ),
    );
  }
}
