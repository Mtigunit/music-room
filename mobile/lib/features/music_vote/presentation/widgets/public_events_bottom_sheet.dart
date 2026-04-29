import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/widgets/empty_state_widget.dart';
import 'package:music_room/features/events/data/datasources/event_remote_datasource.dart';
import 'package:music_room/features/music_vote/presentation/state/public_events_cubit.dart';

class PublicEventsBottomSheet extends StatelessWidget {
  const PublicEventsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    final sheetColor = isDark ? const Color(0xFF12131A) : colorScheme.surface;

    return Container(
      height: screenHeight * 0.85,
      decoration: BoxDecoration(
        color: sheetColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Discover Public Events',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.onSurface.withValues(
                        alpha: 0.06,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: BlocBuilder<PublicEventsCubit, PublicEventsState>(
                builder: (context, state) {
                  if (state is PublicEventsLoading ||
                      state is PublicEventsInitial) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (state is PublicEventsError) {
                    return _PublicEventsErrorView(message: state.message);
                  }

                  final loaded = state as PublicEventsLoaded;
                  if (loaded.events.isEmpty) {
                    return const _PublicEventsEmptyView();
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: loaded.events.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final event = loaded.events[index];
                      return _PublicEventTile(
                        event: event,
                        onJoin: () => Navigator.of(context).pop(event),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicEventsErrorView extends StatelessWidget {
  const _PublicEventsErrorView({required this.message});

  final String message;

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
              onPressed: () =>
                  context.read<PublicEventsCubit>().fetchPublicEvents(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicEventsEmptyView extends StatelessWidget {
  const _PublicEventsEmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: EmptyStateWidget(
          icon: Icons.public_off,
          message: 'No public events found right now.',
        ),
      ),
    );
  }
}

class _PublicEventTile extends StatelessWidget {
  const _PublicEventTile({
    required this.event,
    required this.onJoin,
  });

  final MyEventItemModel event;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1B1C25)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          _EventCover(url: event.coverImage),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        event.hostName.isEmpty ? 'Host TBD' : event.hostName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: onJoin,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}

class _EventCover extends StatelessWidget {
  const _EventCover({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final hasImage = url != null && url!.isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 64,
        height: 64,
        child: hasImage
            ? Image.network(
                url!,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _CoverPlaceholder(colorScheme: colorScheme);
                },
                errorBuilder: (context, error, stackTrace) =>
                    _CoverPlaceholder(colorScheme: colorScheme),
              )
            : _CoverPlaceholder(colorScheme: colorScheme),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.headphones,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
