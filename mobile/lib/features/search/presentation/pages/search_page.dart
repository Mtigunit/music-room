import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/home/presentation/widgets/genre_filter_list.dart';
import 'package:music_room/features/playlist/presentation/pages/playlist_details_page.dart';
import 'package:music_room/features/search/data/models/search_filter_type.dart';
import 'package:music_room/features/search/data/models/search_result_models.dart';
import 'package:music_room/features/search/data/services/search_query_service.dart';
import 'package:music_room/features/search/presentation/state/search_cubit.dart';
import 'package:music_room/features/search/presentation/widgets/search_event_result_card.dart';
import 'package:music_room/features/search/presentation/widgets/search_field.dart';
import 'package:music_room/features/search/presentation/widgets/search_message_state.dart';
import 'package:music_room/features/search/presentation/widgets/search_result_card.dart';
import 'package:music_room/features/search/presentation/widgets/search_track_result_card.dart';
import 'package:music_room/features/search/presentation/widgets/search_user_result_card.dart';
import 'package:music_room/features/search/presentation/widgets/skeletons/search_results_skeleton.dart';
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
  final TextEditingController _searchController = TextEditingController();
  final SearchQueryService _searchQueryService =
      InjectionContainer().searchQueryService;
  late final SearchCubit _searchCubit;

  @override
  void initState() {
    super.initState();
    _searchCubit = SearchCubit(
      remoteDataSource: InjectionContainer().searchRemoteDataSource,
    );
    _searchController.addListener(_normalizeControllerSelection);

    final initialQuery = _searchQueryService.currentQuery.trim().isNotEmpty
        ? _searchQueryService.currentQuery.trim()
        : (widget.initialQuery?.trim() ?? '');

    if (initialQuery.isNotEmpty) {
      _searchController.value = TextEditingValue(
        text: initialQuery,
        selection: TextSelection.collapsed(offset: initialQuery.length),
      );
      _searchQueryService.currentQuery = initialQuery;
    }

    _searchCubit.hydrate(
      query: initialQuery,
      filter: SearchFilterType.events,
    );
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
    _searchController
      ..removeListener(_normalizeControllerSelection)
      ..dispose();
    unawaited(_searchCubit.close());
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _searchQueryService.currentQuery = value;
    _searchCubit.updateQuery(value);
  }

  void _onSubmitted(String value) {
    _searchQueryService.currentQuery = value;
    _searchCubit.submitQuery(value);
  }

  void _onFilterChanged(SearchFilterType filter) {
    _searchCubit.changeFilter(filter);
  }

  void _navigateBackToHome() {
    _searchQueryService.clearQuery();

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

    return BlocProvider.value(
      value: _searchCubit,
      child: PopScope<Object?>(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) {
            _searchQueryService.clearQuery();
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
                          onSubmitted: _onSubmitted,
                        ),
                      ),
                    ],
                  ),
                ),
                BlocBuilder<SearchCubit, SearchState>(
                  builder: (context, state) {
                    return HorizontalFilterList(
                      items: filters.map(_filterLabel).toList(growable: false),
                      selectedIndex: filters.indexOf(state.filter),
                      onSelected: (index) {
                        _onFilterChanged(filters[index]);
                      },
                      itemPadding: const EdgeInsets.symmetric(horizontal: 20),
                      listPadding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ColoredBox(
                    color: resultsBackgroundColor,
                    child: BlocBuilder<SearchCubit, SearchState>(
                      builder: (context, state) {
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: _buildBodyState(context, state),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBodyState(BuildContext context, SearchState state) {
    final query = state.query.trim();
    final filterLabel = _filterLabel(state.filter);
    final label = filterLabel.toLowerCase();
    final quotedQuery = '"$query"';
    final emptyMessage = 'Type something above to find $label results.';
    final noResultsMessage =
        'No $label matched $quotedQuery. Try a different search term.';

    if (!state.hasQuery) {
      return SearchMessageState(
        key: ValueKey<String>('empty-$filterLabel'),
        icon: Icons.search,
        title: 'Search ${filterLabel.toLowerCase()}',
        message: emptyMessage,
      );
    }

    if (state.isLoading) {
      return SearchResultsSkeleton(
        key: ValueKey<String>('loading-$filterLabel'),
        filter: state.filter,
      );
    }

    if (state.hasError) {
      return SearchMessageState(
        key: ValueKey<String>('error-$filterLabel'),
        icon: Icons.cloud_off_rounded,
        title: 'Unable to load results',
        message: state.errorMessage ?? 'Please try again.',
        actionLabel: 'Retry',
        onActionPressed: _searchCubit.retry,
      );
    }

    if (state.isEmpty) {
      return SearchMessageState(
        key: ValueKey<String>('empty-results-$filterLabel'),
        icon: Icons.inbox_outlined,
        title: 'No results found',
        message: noResultsMessage,
      );
    }

    return LayoutBuilder(
      key: ValueKey<String>('results-$filterLabel'),
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final padding = EdgeInsets.fromLTRB(
          isWide ? 28 : 20,
          4,
          isWide ? 28 : 20,
          20,
        );

        return ListView.separated(
          padding: padding,
          itemCount: state.results.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = state.results[index];
            return _buildResultCard(item);
          },
        );
      },
    );
  }

  Widget _buildResultCard(SearchResultModel item) {
    switch (item.filterType) {
      case SearchFilterType.tracks:
        return SearchTrackResultCard(item: item as SearchTrackResultModel);
      case SearchFilterType.users:
        final user = item as SearchUserResultModel;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              unawaited(
                Navigator.of(context).pushNamed(
                  RouteNames.profile,
                  arguments: user.id,
                ),
              );
            },
            child: SearchUserResultCard(item: user),
          ),
        );
      case SearchFilterType.events:
        final event = item as SearchEventResultModel;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              unawaited(
                Navigator.of(context).pushNamed(
                  RouteNames.preEvent,
                  arguments: event.id,
                ),
              );
            },
            child: SearchEventResultCard(item: event),
          ),
        );
      case SearchFilterType.playlists:
        final playlist = item as SearchPlaylistResultModel;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              unawaited(
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PlaylistDetailsPage(
                      playlistId: playlist.id,
                      playlistName: playlist.name,
                    ),
                  ),
                ),
              );
            },
            child: SearchPlaylistResultCard(item: playlist),
          ),
        );
    }
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
