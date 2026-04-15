import 'package:flutter/material.dart';

class PageIndicator extends StatelessWidget {
  final int currentIndex;
  final int pageCount;

  const PageIndicator({
    super.key,
    required this.currentIndex,
    this.pageCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(pageCount, (index) {
        final isActive = index == currentIndex;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(right: 6.0),
          width: isActive ? 24.0 : 6.0,
          height: 6.0,
          decoration: BoxDecoration(
            color: isActive ? colorScheme.primary : colorScheme.secondary,
            borderRadius: BorderRadius.circular(4.0),
          ),
        );
      }),
    );
  }
}
