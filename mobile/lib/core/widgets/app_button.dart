import 'package:flutter/material.dart';

enum AppButtonVariant { filled, outlined, text }

class AppButton extends StatelessWidget {
  const AppButton({
    required this.onPressed,
    super.key,
    this.variant = AppButtonVariant.filled,
    this.label,
    this.child,
    this.textStyle,
    this.leading,
    this.trailing,
    this.isLoading = false,
    this.backgroundColor,
    this.foregroundColor,
    this.disabledBackgroundColor,
    this.disabledForegroundColor,
    this.borderSide,
    this.borderRadius = 12,
    this.padding,
  }) : assert(
         label != null || child != null,
         'Provide either label or child for AppButton.',
       );

  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final String? label;
  final Widget? child;
  final TextStyle? textStyle;
  final Widget? leading;
  final Widget? trailing;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? disabledBackgroundColor;
  final Color? disabledForegroundColor;
  final BorderSide? borderSide;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedForeground =
        foregroundColor ??
        (variant == AppButtonVariant.filled
            ? colorScheme.onPrimary
            : colorScheme.primary);

    final content = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(resolvedForeground),
            ),
          )
        : (child ?? _buildLabelContent(resolvedForeground));

    final resolvedOnPressed = isLoading ? null : onPressed;

    switch (variant) {
      case AppButtonVariant.filled:
        return ElevatedButton(
          onPressed: resolvedOnPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor ?? colorScheme.primary,
            foregroundColor: resolvedForeground,
            disabledBackgroundColor: disabledBackgroundColor,
            disabledForegroundColor: disabledForegroundColor,
            padding: padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
          child: content,
        );
      case AppButtonVariant.outlined:
        return OutlinedButton(
          onPressed: resolvedOnPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: resolvedForeground,
            disabledForegroundColor: disabledForegroundColor,
            side: borderSide ?? BorderSide(color: colorScheme.outlineVariant),
            padding: padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
          child: content,
        );
      case AppButtonVariant.text:
        return TextButton(
          onPressed: resolvedOnPressed,
          style: TextButton.styleFrom(
            foregroundColor: resolvedForeground,
            disabledForegroundColor: disabledForegroundColor,
            padding: padding,
            textStyle: textStyle,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
          child: content,
        );
    }
  }

  Widget _buildLabelContent(Color resolvedForeground) {
    final labelWidget = Text(
      label!,
      style:
          textStyle?.copyWith(color: resolvedForeground) ??
          TextStyle(color: resolvedForeground),
    );

    if (leading == null && trailing == null) {
      return labelWidget;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 8),
        ],
        labelWidget,
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}
