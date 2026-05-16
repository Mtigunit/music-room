import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/events/domain/entities/event_tag.dart';
import 'package:music_room/features/events/domain/entities/my_event_item_model.dart';
import 'package:music_room/features/events/presentation/pages/create_event_page.dart';
import 'package:music_room/features/home/presentation/state/home_events_cubit.dart';
import 'package:music_room/features/home/presentation/state/home_events_state.dart';
import 'package:music_room/features/home/presentation/widgets/event_see_all_sheet.dart';
import 'package:music_room/features/home/presentation/widgets/event_vertical_card.dart';
import 'package:music_room/features/home/presentation/widgets/genre_filter_list.dart';
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
  int _selectedGenreIndex = 0;
  int _selectedStatusIndex = 0;

  static const List<String> statuses = ['All', 'Live', 'Upcoming', 'Ended'];
  List<String> get _tagLabels => [
    'All',
    ...EventTag.values.map((e) => e.label),
  ];

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
              floatingActionButton: FloatingActionButton.extended(
                heroTag: null,
                onPressed: () {
                  unawaited(
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const CreateEventPage(),
                      ),
                    ),
                  );
                },
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                icon: const Icon(Icons.add),
                label: const Text(
                  'Create Event',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              body: RefreshIndicator(
                onRefresh: () => _cubit.fetchEvents(),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _HeaderAndFilters(
                        cubit: _cubit,
                        selectedStatusIndex: _selectedStatusIndex,
                        onStatusSelected: (index) {
                          setState(() {
                            _selectedStatusIndex = index;
                          });
                          final status = statuses[index];
                          unawaited(
                            _cubit.fetchEvents(
                              status: status == 'All' ? '' : status,
                            ),
                          );
                        },
                        selectedGenreIndex: _selectedGenreIndex,
                        onGenreSelected: (index) {
                          setState(() {
                            _selectedGenreIndex = index;
                          });
                          final tag = index == 0
                              ? ''
                              : EventTag.values[index - 1].backendValue;
                          unawaited(
                            _cubit.fetchEvents(
                              tags: tag,
                            ),
                          );
                        },
                        statuses: statuses,
                        tagLabels: _tagLabels,
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
    required this.selectedStatusIndex,
    required this.onStatusSelected,
    required this.selectedGenreIndex,
    required this.onGenreSelected,
    required this.statuses,
    required this.tagLabels,
  });

  final HomeEventsCubit cubit;
  final int selectedStatusIndex;
  final ValueChanged<int> onStatusSelected;
  final int selectedGenreIndex;
  final ValueChanged<int> onGenreSelected;
  final List<String> statuses;
  final List<String> tagLabels;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
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
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'STATUS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          HorizontalFilterList(
            items: statuses,
            selectedIndex: selectedStatusIndex,
            onSelected: onStatusSelected,
            listPadding: const EdgeInsets.symmetric(horizontal: 24),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'TAGS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          HorizontalFilterList(
            items: tagLabels,
            selectedIndex: selectedGenreIndex,
            onSelected: onGenreSelected,
            listPadding: const EdgeInsets.symmetric(horizontal: 24),
          ),
          const SizedBox(height: 32),
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
