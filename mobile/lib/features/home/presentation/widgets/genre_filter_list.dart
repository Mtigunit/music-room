import 'dart:async';

import 'package:flutter/material.dart';

class HorizontalFilterList extends StatefulWidget {
  const HorizontalFilterList({
    required this.items,
    this.selectedIndex = 0,
    this.onSelected,
    this.height = 40,
    this.itemSpacing = 12,
    this.itemPadding = const EdgeInsets.symmetric(horizontal: 24),
    this.listPadding,
    this.borderRadius = 20,
    this.fontSize = 14,
    this.selectedFontWeight = FontWeight.w600,
    this.unselectedFontWeight = FontWeight.w500,
    super.key,
  });

  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int>? onSelected;
  final double height;
  final double itemSpacing;
  final EdgeInsetsGeometry itemPadding;
  final EdgeInsetsGeometry? listPadding;
  final double borderRadius;
  final double fontSize;
  final FontWeight selectedFontWeight;
  final FontWeight unselectedFontWeight;

  @override
  State<HorizontalFilterList> createState() => _HorizontalFilterListState();
}

class _HorizontalFilterListState extends State<HorizontalFilterList> {
  final ScrollController _scrollController = ScrollController();
  bool _showLeftArrow = false;
  bool _showRightArrow = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateArrows);
    // Use addPostFrameCallback to check if scroll is possible after first build
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _updateArrows() {
    if (!mounted) return;

    final hasContentToScrollLeft = _scrollController.offset > 10;
    final hasContentToScrollRight =
        _scrollController.offset <
        _scrollController.position.maxScrollExtent - 10;

    if (_showLeftArrow != hasContentToScrollLeft ||
        _showRightArrow != hasContentToScrollRight) {
      setState(() {
        _showLeftArrow = hasContentToScrollLeft;
        _showRightArrow = hasContentToScrollRight;
      });
    }
  }

  void _scrollLeft() {
    unawaited(
      _scrollController.animateTo(
        (_scrollController.offset - 150).clamp(
          0,
          _scrollController.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ),
    );
  }

  void _scrollRight() {
    unawaited(
      _scrollController.animateTo(
        (_scrollController.offset + 150).clamp(
          0,
          _scrollController.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          // The List
          Positioned.fill(
            child: ListView.separated(
              controller: _scrollController,
              clipBehavior: Clip.none,
              padding: widget.listPadding,
              scrollDirection: Axis.horizontal,
              itemCount: widget.items.length,
              separatorBuilder: (_, _) => SizedBox(width: widget.itemSpacing),
              itemBuilder: (context, index) {
                final isSelected = index == widget.selectedIndex;

                return GestureDetector(
                  onTap: () => widget.onSelected?.call(index),
                  child: Container(
                    padding: widget.itemPadding,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                      border: isSelected
                          ? null
                          : Border.all(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.1,
                              ),
                            ),
                    ),
                    child: Text(
                      widget.items[index],
                      style: TextStyle(
                        color: isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface.withValues(alpha: 0.7),
                        fontWeight: isSelected
                            ? widget.selectedFontWeight
                            : widget.unselectedFontWeight,
                        fontSize: widget.fontSize,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Left Gradient & Arrow
          if (_showLeftArrow)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Row(
                children: [
                  Container(
                    width: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          scaffoldBg,
                          scaffoldBg.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_showLeftArrow)
            Positioned(
              left: -8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  onPressed: _scrollLeft,
                  icon: const Icon(Icons.chevron_left_rounded),
                  color: colorScheme.primary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ),

          // Right Gradient & Arrow
          if (_showRightArrow)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Row(
                children: [
                  Container(
                    width: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          scaffoldBg,
                          scaffoldBg.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_showRightArrow)
            Positioned(
              right: -8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  onPressed: _scrollRight,
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: colorScheme.primary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class GenreFilterList extends StatelessWidget {
  const GenreFilterList({
    super.key,
    this.selectedIndex = 0,
    this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int>? onSelected;

  static const List<String> genres = [
    'All',
    'Electronic',
    'Hip Hop',
    'Lo-Fi',
    'Pop',
    'Jazz',
  ];

  @override
  Widget build(BuildContext context) {
    return HorizontalFilterList(
      items: genres,
      selectedIndex: selectedIndex,
      onSelected: onSelected,
    );
  }
}
