import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/home/presentation/widgets/genre_filter_list.dart';
import 'package:music_room/features/search/data/datasources/search_remote_datasource.dart';
import 'package:music_room/features/search/data/services/search_query_service.dart';
import 'package:music_room/routes/route_names.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    this.initialQuery,
  });

  final String? initialQuery;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const Duration _debounceDuration = Duration(milliseconds: 450);

  final TextEditingController _searchController = TextEditingController();
  final ISearchRemoteDataSource _searchDataSource =
      InjectionContainer().searchRemoteDataSource;
  final SearchQueryService _searchQueryService =
      InjectionContainer().searchQueryService;

  Timer? _debounce;
  int _requestId = 0;
  SearchFilterType _selectedFilter = SearchFilterType.events;
  List<SearchResultItem> _results = const <SearchResultItem>[];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_normalizeControllerSelection);

    // Use shared query first, then fallback to initial query.
    var queryToUse = _searchQueryService.currentQuery.trim();
    if (queryToUse.isEmpty) {
      queryToUse = widget.initialQuery?.trim() ?? '';
    }

    if (queryToUse.isNotEmpty) {
      _searchController.value = TextEditingValue(
        text: queryToUse,
        selection: TextSelection.collapsed(offset: queryToUse.length),
      );
      _searchQueryService.currentQuery = queryToUse;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(_performSearch(queryToUse));
      });
    }
  }

  void _normalizeControllerSelection() {
    final value = _searchController.value;
    if (value.text.isNotEmpty && !value.selection.isValid) {
      _searchController.value = value.copyWith(
        selection: TextSelection.collapsed(offset: value.text.length),
        composing: TextRange.empty,
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController
      ..removeListener(_normalizeControllerSelection)
      ..dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    // Update the shared query service
    _searchQueryService.currentQuery = value;

    if (value.trim().isEmpty) {
      _debounce?.cancel();
      _navigateBackToHome();
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      if (!mounted) {
        return;
      }
      unawaited(_performSearch(value));
    });
  }

  Future<void> _performSearch(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      _navigateBackToHome();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final currentRequestId = ++_requestId;

    try {
      final List<SearchResultItem> fetchedResults;

      switch (_selectedFilter) {
        case SearchFilterType.tracks:
          fetchedResults = await _searchDataSource.searchTracks(trimmedQuery);
        case SearchFilterType.users:
          fetchedResults = await _searchDataSource.searchUsers(trimmedQuery);
        case SearchFilterType.events:
          fetchedResults = await _searchDataSource.searchEvents(trimmedQuery);
        case SearchFilterType.playlists:
          fetchedResults = await _searchDataSource.searchPlaylists(
            trimmedQuery,
          );
      }

      if (!mounted || currentRequestId != _requestId) {
        return;
      }

      setState(() {
        _results = fetchedResults;
        _isLoading = false;
      });
    } on DioException catch (error) {
      if (!mounted || currentRequestId != _requestId) {
        return;
      }
      setState(() {
        _isLoading = false;
        _results = const <SearchResultItem>[];
        _errorMessage = _buildNetworkErrorMessage(error);
      });
    } on Object {
      if (!mounted || currentRequestId != _requestId) {
        return;
      }
      setState(() {
        _isLoading = false;
        _results = const <SearchResultItem>[];
        _errorMessage =
            'Something went wrong while searching. Please try again.';
      });
    }
  }

  void _navigateBackToHome() {
    _clearSearchState();

    if (!mounted) {
      return;
    }

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    unawaited(
      navigator.pushNamedAndRemoveUntil(RouteNames.home, (_) => false),
    );
  }

  void _clearSearchState() {
    _debounce?.cancel();
    _requestId++;
    _searchQueryService.clearQuery();

    _searchController.clear();
    _results = const <SearchResultItem>[];
    _errorMessage = null;
    _isLoading = false;
  }

  String _buildNetworkErrorMessage(DioException error) {
    if (error.response?.statusCode == 400) {
      return 'Please enter a more specific search query.';
    }

    return 'Unable to fetch search results right now.';
  }

  void _onFilterChanged(SearchFilterType filter) {
    if (_selectedFilter == filter) {
      return;
    }

    setState(() {
      _selectedFilter = filter;
      _results = const <SearchResultItem>[];
      _errorMessage = null;
    });

    final currentQuery = _searchController.text.trim();
    if (currentQuery.isNotEmpty) {
      unawaited(_performSearch(currentQuery));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final resultsBackgroundColor = theme.brightness == Brightness.dark
        ? colorScheme.onSurface.withValues(alpha: 0.08)
        : colorScheme.onSurface.withValues(alpha: 0.03);
    final horizontalPadding = MediaQuery.sizeOf(context).width >= 720
        ? 32.0
        : 20.0;
    const filters = <SearchFilterType>[
      SearchFilterType.events,
      SearchFilterType.tracks,
      SearchFilterType.users,
      SearchFilterType.playlists,
    ];

    return PopScope<Object?>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _clearSearchState();
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding - 8,
                  8,
                  horizontalPadding,
                  12,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _navigateBackToHome,
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _SearchField(
                        controller: _searchController,
                        onChanged: _onQueryChanged,
                        onSubmitted: _performSearch,
                      ),
                    ),
                  ],
                ),
              ),
              HorizontalFilterList(
                items: filters.map(_filterLabel).toList(growable: false),
                selectedIndex: filters.indexOf(_selectedFilter),
                onSelected: (index) => _onFilterChanged(filters[index]),
                itemPadding: const EdgeInsets.symmetric(horizontal: 20),
                listPadding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ColoredBox(
                  color: resultsBackgroundColor,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _buildBodyState(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBodyState(BuildContext context) {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      return _SearchMessageState(
        key: const ValueKey<String>('empty-query'),
        icon: Icons.search,
        title: 'Search ${_filterLabel(_selectedFilter).toLowerCase()}',
        message:
            'Type something above to find '
            '${_filterLabel(_selectedFilter).toLowerCase()} results.',
      );
    }

    if (_isLoading) {
      return const Center(
        key: ValueKey<String>('loading'),
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _SearchMessageState(
        key: const ValueKey<String>('error'),
        icon: Icons.error_outline,
        title: 'Unable to load results',
        message: _errorMessage!,
      );
    }

    if (_results.isEmpty) {
      final emptyMessage = _selectedFilter == SearchFilterType.users
          ? 'No users matched "$query". Try a different name or search '
                'term.'
          : 'No ${_filterLabel(_selectedFilter).toLowerCase()} matched '
                '"$query".';

      return _SearchMessageState(
        key: const ValueKey<String>('empty-results'),
        icon: Icons.inbox_outlined,
        title: 'No results found',
        message: emptyMessage,
      );
    }

    return LayoutBuilder(
      key: const ValueKey<String>('results'),
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        if (_selectedFilter == SearchFilterType.tracks) {
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
              isWide ? 28 : 20,
              4,
              isWide ? 28 : 20,
              20,
            ),
            itemCount: _results.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _TrackResultCard(item: _results[index]);
            },
          );
        }

        return GridView.builder(
          padding: EdgeInsets.fromLTRB(
            isWide ? 28 : 20,
            4,
            isWide ? 28 : 20,
            20,
          ),
          itemCount: _results.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 2 : 1,
            childAspectRatio: isWide ? 3.7 : 3.2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            return _SearchResultCard(item: _results[index]);
          },
        );
      },
    );
  }

  String _filterLabel(SearchFilterType filter) {
    switch (filter) {
      case SearchFilterType.events:
        return 'Events';
      case SearchFilterType.tracks:
        return 'Tracks';
      case SearchFilterType.users:
        return 'Users';
      case SearchFilterType.playlists:
        return 'Playlists';
    }
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return TextField(
          controller: controller,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search tracks, users, events, playlists...',
            prefixIcon: Icon(
              Icons.search,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                    icon: const Icon(Icons.close),
                  )
                : null,
            filled: true,
            fillColor: colorScheme.secondary.withValues(alpha: 0.45),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: colorScheme.primary,
                width: 1.4,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TrackResultCard extends StatelessWidget {
  const _TrackResultCard({required this.item});

  final SearchResultItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _TrackThumbnail(imageUrl: item.imageUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.subtitle}'
                  '${item.meta != null && item.meta!.isNotEmpty ? ' · '
                            '${item.meta}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<_TrackAction>(
            tooltip: 'Track actions',
            offset: const Offset(0, 45),
            elevation: 10,
            constraints: const BoxConstraints(minWidth: 250),
            splashRadius: 20,
            onSelected: (action) => _handleTrackAction(context, action),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            color: colorScheme.surface.withValues(alpha: 0.98),
            surfaceTintColor: colorScheme.surface.withValues(alpha: 0.98),
            padding: EdgeInsets.zero,
            itemBuilder: (context) => [
              const PopupMenuItem<_TrackAction>(
                value: _TrackAction.addToEvent,
                child: _TrackMenuActionItem(
                  icon: Icons.event,
                  title: 'Add to event',
                  subtitle: 'Queue this track for one of your events',
                ),
              ),
              PopupMenuDivider(
                height: 4,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
              ),
              const PopupMenuItem<_TrackAction>(
                value: _TrackAction.saveToPlaylist,
                child: _TrackMenuActionItem(
                  icon: Icons.playlist_add,
                  title: 'Save to playlist',
                  subtitle: 'Add this track to one of your playlists',
                ),
              ),
            ],
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.14),
                    colorScheme.primary.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Icon(
                Icons.more_horiz_rounded,
                color: colorScheme.primary,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleTrackAction(BuildContext context, _TrackAction action) {
    switch (action) {
      case _TrackAction.addToEvent:
        AppSnackbar.showSuccess(
          context,
          'Added "${item.title}" to your event shortlist.',
        );
        return;
      case _TrackAction.saveToPlaylist:
        AppSnackbar.showSuccess(
          context,
          'Saved "${item.title}" to your playlist.',
        );
        return;
    }
  }
}

class _TrackMenuActionItem extends StatelessWidget {
  const _TrackMenuActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: colorScheme.primary.withValues(alpha: 0.6),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.62),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({required this.item});

  final SearchResultItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: colorScheme.secondary.withValues(alpha: 0.8),
            ),
            child: hasImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        _iconForFilter(item.filterType),
                        color: colorScheme.primary,
                      ),
                    ),
                  )
                : Icon(
                    _iconForFilter(item.filterType),
                    color: colorScheme.primary,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          if (item.meta != null && item.meta!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                item.meta!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconForFilter(SearchFilterType filter) {
    switch (filter) {
      case SearchFilterType.tracks:
        return Icons.music_note;
      case SearchFilterType.users:
        return Icons.person;
      case SearchFilterType.events:
        return Icons.event;
      case SearchFilterType.playlists:
        return Icons.queue_music;
    }
  }
}

class _TrackThumbnail extends StatelessWidget {
  const _TrackThumbnail({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: colorScheme.secondary.withValues(alpha: 0.85),
      ),
      child: hasImage
          ? ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.music_note,
                  color: colorScheme.primary,
                ),
              ),
            )
          : Icon(
              Icons.music_note,
              color: colorScheme.primary,
            ),
    );
  }
}

enum _TrackAction { addToEvent, saveToPlaylist }

class _SearchMessageState extends StatelessWidget {
  const _SearchMessageState({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.68),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
