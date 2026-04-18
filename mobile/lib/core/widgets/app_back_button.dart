import 'package:flutter/material.dart';

class AppBackButton extends StatelessWidget {
  const AppBackButton({
    required this.onPressed,
    super.key,
    this.color,
    this.padding = const EdgeInsets.all(16),
    this.iconSize = 20,
  });

  final VoidCallback onPressed;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        color ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black87);

    return IconButton(
      onPressed: onPressed,
      padding: padding,
      iconSize: iconSize,
      color: resolvedColor,
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      icon: const Icon(Icons.arrow_back_ios_new),
    );
  }
}
