import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/home/presentation/widgets/genre_filter_list.dart';
import 'package:music_room/features/search/data/datasources/search_remote_datasource.dart';
import 'package:music_room/features/search/data/services/search_query_service.dart';
import 'package:music_room/features/search/presentation/widgets/search_field.dart';
import 'package:music_room/features/search/presentation/widgets/search_message_state.dart';
import 'package:music_room/features/search/presentation/widgets/search_result_card.dart';
import 'package:music_room/features/search/presentation/widgets/search_track_result_card.dart';
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

    _debounce?.cancel();
    _requestId++;

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
                      child: SearchField(
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
      return SearchMessageState(
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
      return SearchMessageState(
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

      return SearchMessageState(
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
              return TrackResultCard(item: _results[index]);
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
            return SearchResultCard(item: _results[index]);
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
