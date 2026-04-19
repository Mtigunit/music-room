import 'package:flutter/material.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/search/data/services/search_query_service.dart';

class HomeSearchBar extends StatefulWidget {
  const HomeSearchBar({
    super.key,
    this.onSubmitted,
  });

  final ValueChanged<String>? onSubmitted;

  @override
  State<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<HomeSearchBar> {
  late TextEditingController _controller;
  late SearchQueryService _searchQueryService;

  @override
  void initState() {
    super.initState();
    _searchQueryService = InjectionContainer().searchQueryService;
    _controller = TextEditingController(text: _searchQueryService.currentQuery);
    _searchQueryService.queryNotifier.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _searchQueryService.queryNotifier.removeListener(_onQueryChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final newQuery = _searchQueryService.currentQuery;
    if (_controller.text != newQuery) {
      _controller.text = newQuery;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        textInputAction: TextInputAction.search,
        onChanged: (value) {
          _searchQueryService.currentQuery = value;
        },
        onSubmitted: (value) {
          final trimmed = value.trim();
          if (trimmed.isNotEmpty) {
            _searchQueryService.currentQuery = trimmed;
            widget.onSubmitted?.call(trimmed);
          }
        },
        decoration: InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
          hintText: 'Search rooms, tracks, artists...',
          hintStyle: TextStyle(
            color: colorScheme.onSurface.withValues(alpha: 0.4),
            fontSize: 15,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: colorScheme.onSurface.withValues(alpha: 0.4),
            size: 20,
          ),
          prefixIconConstraints: const BoxConstraints(
            minHeight: 20,
            minWidth: 32,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
