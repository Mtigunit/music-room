import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/widgets/empty_state_widget.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/events/data/datasources/event_remote_datasource.dart';
import 'package:music_room/features/events/presentation/pages/create_event_page.dart';
import 'package:music_room/features/music_vote/data/models/my_event_item.dart';
import 'package:music_room/features/music_vote/presentation/state/my_events_cubit.dart';
import 'package:music_room/features/music_vote/presentation/widgets/my_event_list_tile.dart';
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
          return VisibilityDetector(
            key: const Key('my-events-page'),
            onVisibilityChanged: (info) {
              if (info.visibleFraction > 0) {
                unawaited(context.read<MyEventsCubit>().refreshEvents());
              }
            },
            child: const _MyEventsBody(),
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Body (needs DefaultTabController above it)
// ────────────────────────────────────────────────────────────

class _MyEventsBody extends StatelessWidget {
  const _MyEventsBody();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              child: _PremiumTabBar(
                colorScheme: colorScheme,
                isDark: isDark,
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
// Premium segmented tab bar
// ────────────────────────────────────────────────────────────

class _PremiumTabBar extends StatelessWidget {
  const _PremiumTabBar({
    required this.colorScheme,
    required this.isDark,
  });

  final ColorScheme colorScheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        onTap: (_) => context.read<MyEventsCubit>().refreshEvents(),
        indicator: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: colorScheme.onSurface.withValues(alpha: 0.5),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        labelPadding: EdgeInsets.zero,
        tabs: const [
          Tab(text: 'Invited'),
          Tab(text: 'Hosting'),
        ],
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
            onTap: () => _enterRoom(context, event.id, event.status),
          );
        },
      ),
    );
  }

  void _enterRoom(BuildContext context, String eventId, String status) {
    if (status == 'UPCOMING' || status == 'ENDED') {
      unawaited(
        Navigator.of(context).pushNamed(
          RouteNames.preEvent,
          arguments: eventId,
        ),
      );
    } else {
      unawaited(
        Navigator.of(context).pushNamed(
          RouteNames.musicVote,
          arguments: eventId,
        ),
      );
    }
  }
}
