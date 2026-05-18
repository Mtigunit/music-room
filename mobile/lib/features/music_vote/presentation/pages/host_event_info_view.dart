import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:music_room/core/config/app_config.dart';
import 'package:music_room/core/widgets/dynamic_search_bottom_sheet.dart';
import 'package:music_room/core/widgets/feature_chip.dart';
import 'package:music_room/core/widgets/track_search_list_tile.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/events/presentation/state/track_search_cubit.dart';
import 'package:music_room/features/music_vote/data/models/event_detail_model.dart';
import 'package:music_room/features/music_vote/data/models/event_track_model.dart';
import 'package:music_room/features/music_vote/presentation/state/music_vote_cubit.dart';
import 'package:music_room/features/music_vote/presentation/widgets/event_actions_row.dart';

class HostEventInfoView extends StatelessWidget {
  const HostEventInfoView({
    required this.event,
    required this.tracks,
    super.key,
  });

  final EventDetailModel event;
  final List<EventTrackModel> tracks;

  String? _buildCoverImageUrl(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return null;
    if (relativePath.startsWith('http')) return relativePath;

    final base = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final path = relativePath.replaceAll(RegExp('^/+'), '');
    return '$base/$path';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final safeAreaTop = MediaQuery.paddingOf(context).top;
    final heroHeight = (MediaQuery.sizeOf(context).width * 0.56).clamp(
      180.0,
      250.0,
    );
    var artworkUrl = _buildCoverImageUrl(event.coverImage);
    if ((artworkUrl == null || artworkUrl.isEmpty) && tracks.isNotEmpty) {
      artworkUrl = tracks.first.thumbnailUrl;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            style: IconButton.styleFrom(
              foregroundColor: colorScheme.onSurface,
              backgroundColor: colorScheme.surface,
              shape: const CircleBorder(),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _StatusBadge(colorScheme: colorScheme, status: event.status),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _EventHeroImage(
                imageUrl: artworkUrl,
                height: heroHeight + safeAreaTop,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _EventInfoSection(
                  event: event,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  isDark: isDark,
                ),
              ),
            ),
            if (event.status != 'ENDED')
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: EventActionsRow(
                    event: event,
                    colorScheme: colorScheme,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Queue',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      '${tracks.length} tracks',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (tracks.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 32,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.queue_music_rounded,
                          size: 48,
                          color: colorScheme.onSurface.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No tracks yet\nAdd songs to build your queue!',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(
                              alpha: 0.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: tracks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    return _PreEventTrackItem(
                      track: track,
                      rank: index + 1,
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                      isDark: isDark,
                      eventId: event.id,
                      isEnded: event.status == 'ENDED',
                    );
                  },
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      bottomNavigationBar: event.status == 'ENDED'
          ? const _EventEndedBottomBar()
          : _StartEventBottomBar(eventId: event.id),
    );
  }
}

// EventActionsRow has been extracted to a separate widget file.

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.colorScheme, required this.status});
  final ColorScheme colorScheme;
  final String status;

  @override
  Widget build(BuildContext context) {
    final isEnded = status == 'ENDED';
    final bgColor = isEnded ? Colors.grey.shade700 : colorScheme.primary;
    final icon = isEnded ? Icons.stop_circle_rounded : Icons.schedule_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            status,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventHeroImage extends StatelessWidget {
  const _EventHeroImage({required this.height, required this.imageUrl});
  final double height;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: colorScheme.surfaceContainer,
            child: hasImage
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Center(
                      child: Icon(
                        Icons.celebration_rounded,
                        size: 64,
                        color: colorScheme.primary,
                      ),
                    ),
                  )
                : Center(
                    child: Icon(
                      Icons.celebration_rounded,
                      size: 64,
                      color: colorScheme.primary,
                    ),
                  ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: height * 0.38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.surface.withValues(alpha: 0),
                    colorScheme.surface.withValues(alpha: 0.24),
                    colorScheme.surface,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventInfoSection extends StatelessWidget {
  const _EventInfoSection({
    required this.event,
    required this.colorScheme,
    required this.textTheme,
    required this.isDark,
  });
  final EventDetailModel event;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          event.name,
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            fontSize: 26,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              event.visibility == 'PUBLIC'
                  ? Icons.public_rounded
                  : Icons.lock_rounded,
              size: 16,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 4),
            Text(
              event.visibility == 'PUBLIC' ? 'Public' : 'Private',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (event.startDate != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '•',
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
              ),
              Icon(
                Icons.schedule_rounded,
                size: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 4),
              Text(
                _formatStartDate(event.startDate!),
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        if (event.tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: event.tags
                .map(
                  (tag) => FeatureChip(
                    label: tag,
                    icon: Icons.local_offer_rounded,
                  ),
                )
                .toList(),
          ),
        ],
        if (event.description != null && event.description!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            event.description!,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.65),
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }

  String _formatStartDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);
    final isToday = dateOnly == today;
    final isTomorrow = dateOnly == tomorrow;
    final timeStr = DateFormat.jm().format(date);
    if (isToday) return 'Today at $timeStr';
    if (isTomorrow) return 'Tomorrow at $timeStr';
    return '${DateFormat.MMMd().format(date)} at $timeStr';
  }
}

class AddTracksButton extends StatelessWidget {
  const AddTracksButton({
    required this.eventId,
    required this.colorScheme,
    super.key,
  });
  final String eventId;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showAddTracksSheet(context),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Add Tracks',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddTracksSheet(BuildContext context) async {
    final musicVoteCubit = context.read<MusicVoteCubit>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BlocProvider(
        create: (_) => TrackSearchCubit(
          remoteDataSource: InjectionContainer().trackRemoteDataSource,
        ),
        child: _PreEventAddTrackSheet(
          eventId: eventId,
          musicVoteCubit: musicVoteCubit,
        ),
      ),
    );
  }
}

// InviteUsersButton has been extracted to a separate widget file.

class _PreEventAddTrackSheet extends StatelessWidget {
  const _PreEventAddTrackSheet({
    required this.eventId,
    required this.musicVoteCubit,
  });
  final String eventId;
  final MusicVoteCubit musicVoteCubit;

  @override
  Widget build(BuildContext context) {
    return DynamicSearchBottomSheet(
      title: 'Add Tracks',
      subtitle: 'Build your event queue before going live',
      searchHintText: 'Search for songs, artists, or albums...',
      onSearchChanged: (query) =>
          context.read<TrackSearchCubit>().searchTracks(query),
      content: BlocBuilder<TrackSearchCubit, TrackSearchState>(
        builder: (context, state) {
          if (state is TrackSearchLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is TrackSearchLoaded) {
            return ListView.separated(
              itemCount: state.tracks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final track = state.tracks[index];
                return TrackSearchListTile(
                  track: track,
                  onAddTapped: (added) async =>
                      musicVoteCubit.addTrack(eventId, added.providerTrackId),
                );
              },
            );
          }
          return const Center(child: Text('Search for tracks'));
        },
      ),
    );
  }
}

class _PreEventTrackItem extends StatelessWidget {
  const _PreEventTrackItem({
    required this.track,
    required this.rank,
    required this.colorScheme,
    required this.textTheme,
    required this.isDark,
    required this.eventId,
    this.isEnded = false,
  });
  final EventTrackModel track;
  final int rank;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final bool isDark;
  final String eventId;
  final bool isEnded;

  void _showRemoveConfirmation(BuildContext context) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Remove Track?'),
            content: Text(
              "Are you sure you want to remove '${track.title}' "
              'from the queue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  unawaited(
                    context.read<MusicVoteCubit>().removeTrack(
                      eventId,
                      track.providerTrackId,
                    ),
                  );
                  Navigator.of(dialogContext).pop();
                },
                child: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.07),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: track.thumbnailUrl.isNotEmpty
                ? Image.network(
                    track.thumbnailUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 48,
                    height: 48,
                    color: colorScheme.surfaceContainer,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        track.artist,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!isEnded)
            IconButton(
              onPressed: () => _showRemoveConfirmation(context),
              icon: Icon(
                Icons.close_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.35),
                size: 20,
              ),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

class _StartEventBottomBar extends StatelessWidget {
  const _StartEventBottomBar({required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.paddingOf(context).bottom + 16,
      ),
      child: BlocBuilder<MusicVoteCubit, MusicVoteState>(
        builder: (context, state) {
          return ElevatedButton(
            onPressed: state.isStartingEvent
                ? null
                : () => context.read<MusicVoteCubit>().startEvent(eventId),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (state.isStartingEvent)
                  const CircularProgressIndicator(color: Colors.white)
                else ...[
                  const Text(
                    'Start Event',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.play_arrow_rounded, color: Colors.white),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EventEndedBottomBar extends StatelessWidget {
  const _EventEndedBottomBar();
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.paddingOf(context).bottom + 16,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.done_all_rounded,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            const Text(
              'This event has ended',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
