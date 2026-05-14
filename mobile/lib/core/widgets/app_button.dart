import 'package:flutter/material.dart';

enum AppButtonVariant {
  filled,
  outlined,
  text,
}

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
    this.height,
    this.width,
    this.elevation,
    this.gradient,
    this.expand = false,
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

  final double? height;
  final double? width;

  final double? elevation;

  final Gradient? gradient;

  final bool expand;

  ButtonStyle _baseStyle(
    BuildContext context,
    ColorScheme colorScheme,
    Color resolvedForeground,
  ) {
    return ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        Size(
          expand ? double.infinity : 0,
          height ?? 48,
        ),
      ),
      // Keep max width unconstrained so non-expanded buttons can
      // shrink-wrap to their content. Only limit the max height when
      // `expand` is true (allowing infinite height if no explicit
      // `height` was provided).
      maximumSize: WidgetStatePropertyAll(
        Size(
          double.infinity,
          expand ? (height ?? double.infinity) : (height ?? 48),
        ),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      elevation: WidgetStatePropertyAll(elevation ?? 0),
      padding: WidgetStatePropertyAll(
        padding ??
            const EdgeInsets.symmetric(
              horizontal: 20,
            ),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            borderRadius,
          ),
        ),
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) {
          if (states.contains(
            WidgetState.disabled,
          )) {
            return disabledForegroundColor;
          }

          return resolvedForeground;
        },
      ),
    );
  }

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
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                resolvedForeground,
              ),
            ),
          )
        : (child ??
              _buildLabelContent(
                resolvedForeground,
              ));

    final resolvedOnPressed = isLoading ? null : onPressed;

    Widget button;

    switch (variant) {
      case AppButtonVariant.filled:
        button = ElevatedButton(
          onPressed: resolvedOnPressed,
          style:
              _baseStyle(
                context,
                colorScheme,
                resolvedForeground,
              ).copyWith(
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) {
                    if (gradient != null) {
                      return Colors.transparent;
                    }

                    if (states.contains(
                      WidgetState.disabled,
                    )) {
                      return disabledBackgroundColor;
                    }

                    return backgroundColor ?? colorScheme.primary;
                  },
                ),
                shadowColor: const WidgetStatePropertyAll(
                  Colors.transparent,
                ),
              ),
          child: content,
        );

      case AppButtonVariant.outlined:
        button = OutlinedButton(
          onPressed: resolvedOnPressed,
          style:
              _baseStyle(
                context,
                colorScheme,
                resolvedForeground,
              ).copyWith(
                side: WidgetStatePropertyAll(
                  borderSide ??
                      BorderSide(
                        color: colorScheme.outlineVariant,
                      ),
                ),
                backgroundColor: WidgetStatePropertyAll(
                  backgroundColor,
                ),
              ),
          child: content,
        );

      case AppButtonVariant.text:
        button = TextButton(
          onPressed: resolvedOnPressed,
          style: _baseStyle(
            context,
            colorScheme,
            resolvedForeground,
          ),
          child: content,
        );
    }

    if (gradient != null && variant == AppButtonVariant.filled) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(
            borderRadius,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: button,
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: button,
    );
  }

  Widget _buildLabelContent(
    Color resolvedForeground,
  ) {
    final labelWidget = Text(
      label!,
      style:
          textStyle?.copyWith(
            color: resolvedForeground,
          ) ??
          TextStyle(
            color: resolvedForeground,
          ),
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
