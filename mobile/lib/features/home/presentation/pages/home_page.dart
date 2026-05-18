import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/widgets/app_scaffold.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/events/domain/entities/event_tag.dart';
import 'package:music_room/features/events/domain/entities/my_event_item_model.dart';
import 'package:music_room/features/events/presentation/pages/create_event_page.dart';
import 'package:music_room/features/home/presentation/state/home_events_cubit.dart';
import 'package:music_room/features/home/presentation/state/home_events_state.dart';
import 'package:music_room/features/home/presentation/widgets/event_see_all_sheet.dart';
import 'package:music_room/features/home/presentation/widgets/event_vertical_card.dart';
import 'package:music_room/features/home/presentation/widgets/home_filter_bottom_sheet.dart';
import 'package:music_room/features/home/presentation/widgets/home_header.dart';
import 'package:music_room/features/home/presentation/widgets/home_search_bar.dart';
import 'package:music_room/features/home/presentation/widgets/section_title.dart';
import 'package:music_room/features/music_vote/presentation/pages/guest_music_vote_page.dart';
import 'package:music_room/features/music_vote/presentation/pages/host_music_vote_page.dart';
import 'package:music_room/features/search/presentation/pages/search_page.dart';
import 'package:music_room/routes/route_names.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _selectedStatus;
  List<String> _selectedTags = [];

  static const List<String> statuses = ['All', 'Live', 'Upcoming', 'Ended'];

  final ScrollController _exploreScrollController = ScrollController();
  final ScrollController _friendsScrollController = ScrollController();

  HomeEventsCubit? _cubitInstance;
  HomeEventsCubit get _cubit {
    if (_cubitInstance == null) {
      _cubitInstance = InjectionContainer().createHomeEventsCubit();
      unawaited(_cubitInstance!.fetchEvents());
    }
    return _cubitInstance!;
  }

  @override
  void initState() {
    super.initState();
    // Accessing _cubit triggers the lazy initialization
    _cubit;

    _exploreScrollController.addListener(_onExploreScroll);
    _friendsScrollController.addListener(_onFriendsScroll);
  }

  @override
  void dispose() {
    unawaited(_cubitInstance?.close());
    _exploreScrollController.dispose();
    _friendsScrollController.dispose();
    super.dispose();
  }

  void _onExploreScroll() {
    if (_exploreScrollController.position.pixels >=
        _exploreScrollController.position.maxScrollExtent - 200) {
      unawaited(_cubit.loadMoreExplore());
    }
  }

  void _onFriendsScroll() {
    if (_friendsScrollController.position.pixels >=
        _friendsScrollController.position.maxScrollExtent - 200) {
      unawaited(_cubit.loadMoreFriends());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Builder(
        builder: (context) {
          return SafeArea(
            child: Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              floatingActionButton: FloatingActionButton(
                heroTag: null,
                onPressed: () {
                  unawaited(
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const AppScaffold(
                          foregroundPage: CreateEventPage(),
                        ),
                      ),
                    ),
                  );
                },
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: const CircleBorder(),
                child: const Icon(Icons.add, size: 28),
              ),
              body: RefreshIndicator(
                onRefresh: () => _cubit.fetchEvents(),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _HeaderAndFilters(
                        cubit: _cubit,
                        selectedStatus: _selectedStatus,
                        selectedTags: _selectedTags,
                        statuses: statuses,
                        tags: EventTag.values,
                        onStatusSelected: (status) {
                          setState(() {
                            _selectedStatus = status == 'All' ? null : status;
                          });
                          unawaited(
                            _cubit.fetchEvents(
                              status: _selectedStatus,
                              clearStatus: _selectedStatus == null,
                              tags: _selectedTags.isEmpty
                                  ? null
                                  : _selectedTags,
                              clearTags: _selectedTags.isEmpty,
                            ),
                          );
                        },
                        onTagsUpdated: (tagsList) {
                          setState(() {
                            _selectedTags = tagsList;
                          });
                          unawaited(
                            _cubit.fetchEvents(
                              status: _selectedStatus,
                              clearStatus: _selectedStatus == null,
                              tags: _selectedTags.isEmpty
                                  ? null
                                  : _selectedTags,
                              clearTags: _selectedTags.isEmpty,
                            ),
                          );
                        },
                        onFilterTap: () async {
                          final result = await HomeFilterBottomSheet.show(
                            context,
                            initialStatus: _selectedStatus,
                            initialTags: _selectedTags,
                          );
                          if (result != null) {
                            if (!context.mounted) return;
                            setState(() {
                              _selectedStatus = result['status'] as String?;
                              _selectedTags = (result['tags'] as List<dynamic>)
                                  .cast<String>();
                            });
                            unawaited(
                              _cubit.fetchEvents(
                                status: _selectedStatus,
                                clearStatus: _selectedStatus == null,
                                tags: _selectedTags.isEmpty
                                    ? null
                                    : _selectedTags,
                                clearTags: _selectedTags.isEmpty,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _EventsBody(
                        cubit: _cubit,
                        exploreScrollController: _exploreScrollController,
                        friendsScrollController: _friendsScrollController,
                        onEventTapped: _enterRoom,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _enterRoom(BuildContext context, MyEventItemModel event) async {
    if (event.status == 'UPCOMING' || event.status == 'ENDED') {
      await Navigator.of(context).pushNamed(
        RouteNames.preEvent,
        arguments: event.id,
      );
      return;
    }

    // Get current user ID to decide between Host or Guest view
    var currentUserId = _currentUserId(context);
    if (currentUserId == null || currentUserId.isEmpty) {
      final tokenStorage = InjectionContainer().tokenStorageService;
      final userJson = await tokenStorage.getUserProfile();
      if (userJson != null && userJson.isNotEmpty) {
        try {
          final parsed = jsonDecode(userJson);
          if (parsed is Map<String, dynamic>) {
            currentUserId = (parsed['id'] ?? parsed['userId'])?.toString();
          }
        } on Object catch (_) {}
      }
    }

    if (!context.mounted) return;

    if (currentUserId == event.hostId) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => HostMusicVotePage(eventId: event.id),
        ),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GuestMusicVotePage(eventId: event.id),
        ),
      );
    }
  }

  String? _currentUserId(BuildContext context) {
    return context.read<AuthBloc>().state.currentUser?.id;
  }
}

class _HeaderAndFilters extends StatelessWidget {
  const _HeaderAndFilters({
    required this.cubit,
    required this.selectedStatus,
    required this.selectedTags,
    required this.onStatusSelected,
    required this.onTagsUpdated,
    required this.onFilterTap,
    required this.statuses,
    required this.tags,
  });

  final HomeEventsCubit cubit;
  final String? selectedStatus;
  final List<String> selectedTags;
  final ValueChanged<String> onStatusSelected;
  final ValueChanged<List<String>> onTagsUpdated;
  final VoidCallback onFilterTap;
  final List<String> statuses;
  final List<EventTag> tags;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ignore: prefer_const_constructors
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            // ignore: prefer_const_constructors
            child: HomeHeader(),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: HomeSearchBar(
              onSubmitted: (query) {
                unawaited(
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => SearchPage(initialQuery: query),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  _buildIconButton(context, Icons.tune, onFilterTap),
                  const SizedBox(width: 12),
                  _buildStatusDropdown(context),
                  const SizedBox(width: 12),
                  _buildTagsDropdown(context),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildIconButton(
    BuildContext context,
    IconData icon,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final numFilters = (selectedStatus != null ? 1 : 0) + selectedTags.length;
    final isActive = numFilters > 0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.primary : Colors.transparent,
          border: Border.all(
            color: isActive ? Colors.transparent : theme.colorScheme.primary,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Filter',
              style: TextStyle(
                color: isActive
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$numFilters',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDropdown(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = selectedStatus != null;
    final label = selectedStatus ?? 'Status';

    return Theme(
      data: theme.copyWith(
        hoverColor: theme.colorScheme.primary.withValues(alpha: 0.08),
        splashColor: theme.colorScheme.primary.withValues(alpha: 0.12),
        highlightColor: Colors.transparent,
      ),
      child: PopupMenuButton<String>(
        initialValue: selectedStatus ?? 'All',
        onSelected: onStatusSelected,
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        offset: const Offset(0, 48),
        elevation: 3,
        shadowColor: theme.colorScheme.primary.withValues(alpha: 0.08),
        surfaceTintColor: theme.colorScheme.surface,
        constraints: const BoxConstraints(minWidth: 160, maxWidth: 180),
        itemBuilder: (context) => [
          _buildStatusMenuItem(
            context,
            'All',
            Icons.filter_alt_outlined,
            theme,
          ),
          _buildStatusMenuItem(
            context,
            'Live',
            Icons.sensors,
            theme,
            isLive: true,
          ),
          _buildStatusMenuItem(
            context,
            'Upcoming',
            Icons.upcoming_outlined,
            theme,
          ),
          _buildStatusMenuItem(
            context,
            'Ended',
            Icons.check_circle_outline,
            theme,
          ),
        ],
        child: _buildFilterChipLabel(context, label, isActive),
      ),
    );
  }

  PopupMenuItem<String> _buildStatusMenuItem(
    BuildContext context,
    String value,
    IconData icon,
    ThemeData theme, {
    bool isLive = false,
  }) {
    final isSelected =
        selectedStatus == (value == 'All' ? null : value) ||
        (selectedStatus == null && value == 'All');
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isSelected
                ? theme.colorScheme.primary
                : (isLive
                      ? Colors.redAccent
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
          ],
        ],
      ),
    );
  }

  Widget _buildTagsDropdown(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = selectedTags.isNotEmpty;
    final label = isActive
        ? (selectedTags.length == 1
              ? tags
                    .firstWhere((t) => t.backendValue == selectedTags.first)
                    .label
              : '${selectedTags.length} Tags')
        : 'Tags';

    return Theme(
      data: theme.copyWith(
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: PopupMenuButton<List<String>>(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        offset: const Offset(0, 48),
        constraints: const BoxConstraints(maxWidth: 320),
        elevation: 3,
        shadowColor: theme.colorScheme.primary.withValues(alpha: 0.08),
        surfaceTintColor: theme.colorScheme.surface,
        itemBuilder: (context) {
          return [
            PopupMenuItem<List<String>>(
              enabled: false,
              child: _TagsGridPopupContent(
                initialTags: selectedTags,
                tags: tags,
                onTagsChanged: (newTags) {
                  Navigator.pop(context, newTags);
                },
              ),
            ),
          ];
        },
        onSelected: onTagsUpdated,
        child: _buildFilterChipLabel(context, label, isActive),
      ),
    );
  }

  Widget _buildFilterChipLabel(
    BuildContext context,
    String label,
    bool isActive,
  ) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? theme.colorScheme.primary : Colors.transparent,
        border: Border.all(
          color: isActive ? Colors.transparent : theme.colorScheme.primary,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: isActive
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: isActive
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _TagsGridPopupContent extends StatefulWidget {
  const _TagsGridPopupContent({
    required this.initialTags,
    required this.tags,
    required this.onTagsChanged,
  });

  final List<String> initialTags;
  final List<EventTag> tags;
  final ValueChanged<List<String>> onTagsChanged;

  @override
  State<_TagsGridPopupContent> createState() => _TagsGridPopupContentState();
}

class _TagsGridPopupContentState extends State<_TagsGridPopupContent> {
  late Set<String> _selectedTags;

  @override
  void initState() {
    super.initState();
    _selectedTags = widget.initialTags.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filter by Tags',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedTags.clear();
                  });
                  widget.onTagsChanged([]);
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.tags.map((tag) {
              final isSelected = _selectedTags.contains(tag.backendValue);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedTags.remove(tag.backendValue);
                    } else {
                      _selectedTags.add(tag.backendValue);
                    }
                  });
                  widget.onTagsChanged(_selectedTags.toList());
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : theme.colorScheme.primary,
                      width: 1.2,
                    ),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Text(
                    tag.label,
                    style: TextStyle(
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.primary,
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _TagsOnlySheet extends StatefulWidget {
  const _TagsOnlySheet({required this.initialTags, required this.tags});
  final List<String> initialTags;
  final List<EventTag> tags;

  @override
  State<_TagsOnlySheet> createState() => _TagsOnlySheetState();
}

class _TagsOnlySheetState extends State<_TagsOnlySheet> {
  late Set<String> _selectedTags;

  @override
  void initState() {
    super.initState();
    _selectedTags = widget.initialTags.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);

    return Container(
      height: size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Filter by Tags',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: widget.tags.map((tag) {
                    final isSelected = _selectedTags.contains(tag.backendValue);
                    return FilterChip(
                      label: Text(tag.label),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedTags.add(tag.backendValue);
                          } else {
                            _selectedTags.remove(tag.backendValue);
                          }
                        });
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                      backgroundColor: Colors.transparent,
                      side: BorderSide(
                        color: isSelected
                            ? Colors.transparent
                            : theme.colorScheme.primary,
                      ),
                      selectedColor: theme.colorScheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.primary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      checkmarkColor: theme.colorScheme.onPrimary,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 16,
            ),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedTags.clear();
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                    ),
                    child: const Text(
                      'Clear',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context, _selectedTags.toList());
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                    ),
                    child: const Text(
                      'Show Results',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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

class _EventsBody extends StatelessWidget {
  const _EventsBody({
    required this.cubit,
    required this.exploreScrollController,
    required this.friendsScrollController,
    required this.onEventTapped,
  });

  final HomeEventsCubit cubit;
  final ScrollController exploreScrollController;
  final ScrollController friendsScrollController;
  final void Function(BuildContext, MyEventItemModel) onEventTapped;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeEventsCubit, HomeEventsState>(
      builder: (context, state) {
        if (state is HomeEventsLoading || state is HomeEventsInitial) {
          return const SizedBox(
            height: 300,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is HomeEventsError) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    state.message,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () {
                      unawaited(cubit.fetchEvents());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is HomeEventsSuccess) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                ),
                child: SectionTitle(
                  title: 'Explore Events',
                  subtitle:
                      'Discover public and '
                      'invited music rooms',
                  onSeeAllPressed: () {
                    unawaited(
                      EventSeeAllSheet.show(
                        context,
                        title: 'Explore Events',
                        type: EventListType.explore,
                        cubit: cubit,
                        onEventTapped: onEventTapped,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              _buildHorizontalList(
                context,
                state.exploreEvents,
                exploreScrollController,
                Icons.explore_off_outlined,
                'No public events found.',
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                ),
                child: SectionTitle(
                  title: "Friends' Events",
                  subtitle: 'Events from people you follow',
                  onSeeAllPressed: () {
                    unawaited(
                      EventSeeAllSheet.show(
                        context,
                        title: "Friends' Events",
                        type: EventListType.friends,
                        cubit: cubit,
                        onEventTapped: onEventTapped,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              _buildHorizontalList(
                context,
                state.friendsEvents,
                friendsScrollController,
                Icons.people_outline,
                'None of your friends are currently hosting.',
              ),
              const SizedBox(height: 100),
            ],
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildHorizontalList(
    BuildContext context,
    List<MyEventItemModel> events,
    ScrollController controller,
    IconData emptyIcon,
    String emptyMessage,
  ) {
    if (events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                emptyIcon,
                size: 48,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 160,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = MediaQuery.sizeOf(context).width;
          // Card width is ~45% of the screen width, min 150, max 250
          final cardWidth = (screenWidth * 0.45).clamp(150.0, 250.0);

          return ListView.separated(
            controller: controller,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: events.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final event = events[index];
              return EventVerticalCard(
                event: event,
                width: cardWidth,
                onTap: () => onEventTapped(context, event),
              );
            },
          );
        },
      ),
    );
  }
}
