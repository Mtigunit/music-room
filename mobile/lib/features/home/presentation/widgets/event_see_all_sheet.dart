import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/features/events/domain/entities/my_event_item_model.dart';
import 'package:music_room/features/home/presentation/state/home_events_cubit.dart';
import 'package:music_room/features/home/presentation/state/home_events_state.dart';
import 'package:music_room/features/home/presentation/widgets/event_vertical_card.dart';

enum EventListType { explore, friends }

class EventSeeAllSheet extends StatefulWidget {
  const EventSeeAllSheet({
    required this.title,
    required this.type,
    required this.onEventTapped,
    super.key,
  });

  final String title;
  final EventListType type;
  final void Function(BuildContext, MyEventItemModel) onEventTapped;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required EventListType type,
    required HomeEventsCubit cubit,
    required void Function(BuildContext, MyEventItemModel) onEventTapped,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => BlocProvider.value(
        value: cubit,
        child: EventSeeAllSheet(
          title: title,
          type: type,
          onEventTapped: onEventTapped,
        ),
      ),
    );
  }

  @override
  State<EventSeeAllSheet> createState() => _EventSeeAllSheetState();
}

class _EventSeeAllSheetState extends State<EventSeeAllSheet> {
  void _loadMore(BuildContext context) {
    final cubit = context.read<HomeEventsCubit>();
    if (widget.type == EventListType.explore) {
      unawaited(cubit.loadMoreExplore());
    } else {
      unawaited(cubit.loadMoreFriends());
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag Indicator
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(8, 0, 24, 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      iconSize: 20,
                    ),
                    const Spacer(),
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: BlocBuilder<HomeEventsCubit, HomeEventsState>(
                  builder: (context, state) {
                    if (state is! HomeEventsSuccess) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final events = widget.type == EventListType.explore
                        ? state.exploreEvents
                        : state.friendsEvents;

                    if (events.isEmpty) {
                      return Center(
                        child: Text(
                          'No events found',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                        ),
                      );
                    }

                    return NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification.metrics.pixels >=
                            notification.metrics.maxScrollExtent - 200) {
                          _loadMore(context);
                        }
                        return false;
                      },
                      child: GridView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 24,
                              crossAxisSpacing: 16,
                              // Adjust based on EventVerticalCard content
                              childAspectRatio: 0.75,
                            ),
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final event = events[index];
                          return EventVerticalCard(
                            event: event,
                            width: double.infinity,
                            onTap: () => widget.onEventTapped(context, event),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
