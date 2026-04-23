import 'package:flutter/material.dart';

class DynamicSearchBottomSheet extends StatefulWidget {
  const DynamicSearchBottomSheet({
    required this.title,
    required this.subtitle,
    required this.searchHintText,
    required this.content,
    required this.onSearchChanged,
    this.actionIcon = Icons.close,
    this.onActionPressed,
    super.key,
  });

  final String title;
  final String subtitle;
  final String searchHintText;
  final Widget content;
  final ValueChanged<String> onSearchChanged;
  final IconData actionIcon;
  final VoidCallback? onActionPressed;

  @override
  State<DynamicSearchBottomSheet> createState() =>
      _DynamicSearchBottomSheetState();
}

class _DynamicSearchBottomSheetState extends State<DynamicSearchBottomSheet> {
  final FocusNode _focusNode = FocusNode();
  double _heightFactor = 0.5;
  bool _hasExpanded = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && !_hasExpanded) {
      setState(() {
        _heightFactor = 0.9;
        _hasExpanded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      height: screenSize.height * _heightFactor,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        widget.onActionPressed ??
                        () => Navigator.of(context).pop(),
                    icon: Icon(widget.actionIcon),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.onSurface.withValues(
                        alpha: 0.05,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                widget.subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                focusNode: _focusNode,
                onChanged: widget.onSearchChanged,
                decoration: InputDecoration(
                  hintText: widget.searchHintText,
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(
                        alpha: 0.3,
                      ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: theme.colorScheme.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(child: widget.content),
            ],
          ),
        ),
      ),
    );
  }
}
