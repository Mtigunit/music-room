import 'package:flutter/material.dart';

class PageIndicator extends StatelessWidget {

  const PageIndicator({
    required this.currentIndex, super.key,
    this.pageCount = 3,
  });
  final int currentIndex;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(pageCount, (index) {
        final isActive = index == currentIndex;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: EdgeInsets.only(right: index < pageCount - 1 ? 6.0 : 0.0),
          width: isActive ? 24.0 : 6.0,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? colorScheme.primary : colorScheme.secondary,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
