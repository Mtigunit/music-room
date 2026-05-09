import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/widgets/empty_state_widget.dart';
import 'package:music_room/core/widgets/premium_segmented_tab_bar.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/events/data/datasources/event_remote_datasource.dart';
import 'package:music_room/features/events/presentation/pages/create_event_page.dart';
import 'package:music_room/features/music_vote/data/models/my_event_item.dart';
import 'package:music_room/features/music_vote/presentation/pages/guest_music_vote_page.dart';
import 'package:music_room/features/music_vote/presentation/pages/host_music_vote_page.dart';
import 'package:music_room/features/music_vote/presentation/state/my_events_cubit.dart';
import 'package:music_room/features/music_vote/presentation/state/public_events_cubit.dart';
import 'package:music_room/features/music_vote/presentation/widgets/my_event_list_tile.dart';
import 'package:music_room/features/music_vote/presentation/widgets/public_events_bottom_sheet.dart';
import 'package:music_room/routes/route_names.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// The "My Events" dashboard page.
///
/// Tab 1 — **Invited**: events the current user has been invited to.
/// Tab 2 — **Hosting**: events the current user is hosting.
class MyEventsPage extends StatelessWidget {
  const MyEventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = MyEventsCubit(
          remoteDataSource: InjectionContainer().eventRemoteDataSource,
        );
        unawaited(cubit.fetchEvents());
        return cubit;
      },
      child: Builder(
        builder: (context) {
          final colorScheme = Theme.of(context).colorScheme;

          return Scaffold(
            floatingActionButton: FloatingActionButton(
              heroTag: null,
              onPressed: () => _openDiscoverSheet(context),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              child: const Icon(Icons.public),
            ),
            body: VisibilityDetector(
              key: const Key('my-events-page'),
              onVisibilityChanged: (info) {
                if (info.visibleFraction > 0) {
                  unawaited(context.read<MyEventsCubit>().refreshEvents());
                }
              },
              child: const _MyEventsBody(),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openDiscoverSheet(BuildContext context) async {
    final selectedEvent = await showModalBottomSheet<MyEventItemModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider(
        create: (_) {
          final cubit = PublicEventsCubit(
            eventRepository: InjectionContainer().eventRepository,
          );
          unawaited(cubit.fetchPublicEvents());
          return cubit;
        },
        child: const PublicEventsBottomSheet(),
      ),
    );

    if (!context.mounted) return;

    if (selectedEvent == null) return;

    final uiEvent = MyEventItem(
      id: selectedEvent.id,
      name: selectedEvent.name,
      hostName: selectedEvent.hostName,
      hostId: selectedEvent.hostId,
      dateTime: selectedEvent.startDate,
      status: selectedEvent.status,
      coverImageAsset: selectedEvent.coverImage,
    );

    unawaited(_enterRoom(context, uiEvent));
  }
}

// ────────────────────────────────────────────────────────────
// Body (needs DefaultTabController above it)
// ────────────────────────────────────────────────────────────

class _MyEventsBody extends StatelessWidget {
  const _MyEventsBody();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                24,
                20,
                24,
                4,
              ),
              child: Text(
                'My Events',
                style: textTheme.displaySmall?.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            // ── Tab bar ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
              ),
              child: PremiumSegmentedTabBar(
                onTap: (_) => context.read<MyEventsCubit>().refreshEvents(),
                tabs: const [
                  Tab(text: 'Invited'),
                  Tab(text: 'Hosting'),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── Tab content ───────────────────────────────
            Expanded(
              child: BlocBuilder<MyEventsCubit, MyEventsState>(
                builder: (context, state) {
                  if (state is MyEventsLoading || state is MyEventsInitial) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (state is MyEventsError) {
                    return _ErrorView(
                      message: state.message,
                      onRetry: () =>
                          context.read<MyEventsCubit>().fetchEvents(),
                    );
                  }

                  final success = state as MyEventsSuccess;

                  return TabBarView(
                    children: [
                      _EventListTab(
                        events: success.invitedEvents
                            .map(_toMyEventItem)
                            .toList(growable: false),
                        emptyIcon: Icons.mail_outline_rounded,
                        emptyMessage:
                            "You haven't been invited to any events "
                            'yet.\nDiscover live rooms on '
                            'the Home tab!',
                      ),
                      _EventListTab(
                        events: success.hostedEvents
                            .map(_toMyEventItem)
                            .toList(growable: false),
                        emptyIcon: Icons.spatial_audio_off,
                        emptyMessage:
                            "You aren't hosting any events "
                            'yet.',
                        emptyActionLabel: 'Create Event',
                        onEmptyAction: () => _navigateToCreate(
                          context,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Maps a [MyEventItemModel] (backend DTO) to a [MyEventItem] (UI model).
  MyEventItem _toMyEventItem(MyEventItemModel model) {
    return MyEventItem(
      id: model.id,
      name: model.name,
      hostName: model.hostName,
      hostId: model.hostId,
      dateTime: model.startDate,
      status: model.status,
      // coverImageAsset is not used when a URL is available; the tile falls
      // back to the gradient + icon when null.
      coverImageAsset: model.coverImage,
    );
  }

  void _navigateToCreate(BuildContext context) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const CreateEventPage(),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Error view with retry
// ────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Individual tab list (or empty state)
// ────────────────────────────────────────────────────────────

class _EventListTab extends StatelessWidget {
  const _EventListTab({
    required this.events,
    required this.emptyIcon,
    required this.emptyMessage,
    this.emptyActionLabel,
    this.onEmptyAction,
  });

  final List<MyEventItem> events;
  final IconData emptyIcon;
  final String emptyMessage;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => context.read<MyEventsCubit>().refreshEvents(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: EmptyStateWidget(
              icon: emptyIcon,
              message: emptyMessage,
              actionLabel: emptyActionLabel,
              onActionPressed: onEmptyAction,
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<MyEventsCubit>().refreshEvents(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 16, bottom: 32),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          return MyEventListTile(
            event: event,
            onTap: () => _enterRoom(context, event),
          );
        },
      ),
    );
  }
}

Future<void> _enterRoom(BuildContext context, MyEventItem event) async {
  if (event.status == 'UPCOMING' || event.status == 'ENDED') {
    await Navigator.of(context).pushNamed(
      RouteNames.preEvent,
      arguments: event.id,
    );
    return;
  }

  // Get current user ID to decide between Host or Guest view
  final tokenStorage = InjectionContainer().tokenStorageService;
  final userJson = await tokenStorage.getUserProfile();
  String? currentUserId;

  if (userJson != null && userJson.isNotEmpty) {
    try {
      final parsed = jsonDecode(userJson);
      if (parsed is Map<String, dynamic>) {
        currentUserId = (parsed['id'] ?? parsed['userId']) as String?;
      }
    } on Exception catch (_) {}
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
