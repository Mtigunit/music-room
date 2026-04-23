import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/widgets/empty_state_widget.dart';
import 'package:music_room/features/events/data/models/my_event_item.dart';
import 'package:music_room/features/events/presentation/pages/create_event_page.dart';
import 'package:music_room/features/events/presentation/state/my_events_cubit.dart';
import 'package:music_room/features/events/presentation/widgets/my_event_list_tile.dart';
import 'package:music_room/features/music_vote/presentation/pages/music_vote_page.dart';

/// The "My Events" dashboard page.
///
/// Replaces the previous 2nd bottom-navigation tab.
/// Contains an "Attending" and "Hosting" tab.
class MyEventsPage extends StatelessWidget {
  const MyEventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = MyEventsCubit();
        unawaited(cubit.loadEvents());
        return cubit;
      },
      child: const _MyEventsBody(),
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
                  if (state.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  return TabBarView(
                    children: [
                      _EventListTab(
                        events: state.attendingEvents,
                        emptyIcon: Icons.headphones_outlined,
                        emptyMessage:
                            "You haven't joined any events "
                            'yet.\nDiscover live rooms on '
                            'the Home tab!',
                      ),
                      _EventListTab(
                        events: state.hostingEvents,
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
          Tab(text: 'Attending'),
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
      return EmptyStateWidget(
        icon: emptyIcon,
        message: emptyMessage,
        actionLabel: emptyActionLabel,
        onActionPressed: onEmptyAction,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      itemCount: events.length,
      separatorBuilder: (_, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final event = events[index];
        return MyEventListTile(
          event: event,
          onTap: () => _enterRoom(context, event.id),
        );
      },
    );
  }

  void _enterRoom(BuildContext context, String eventId) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => MusicVotePage(eventId: eventId),
        ),
      ),
    );
  }
}
