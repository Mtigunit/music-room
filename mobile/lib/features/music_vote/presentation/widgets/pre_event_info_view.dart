import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:music_room/core/config/app_config.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/core/widgets/dynamic_search_bottom_sheet.dart';
import 'package:music_room/core/widgets/track_search_list_tile.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/events/presentation/state/track_search_cubit.dart';
import 'package:music_room/features/music_vote/data/models/event_detail_model.dart';
import 'package:music_room/features/music_vote/data/models/event_track_model.dart';
import 'package:music_room/features/music_vote/presentation/state/music_vote_cubit.dart';

/// The "Waiting Room" view shown when the event status is UPCOMING.
///
/// Displays event info (cover, name, description, tags, start date),
/// the current track list, an "Add Tracks" button, and a sticky
/// "🚀 Start Event" button at the bottom.
class PreEventInfoView extends StatelessWidget {
  const PreEventInfoView({
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
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
            ),
            style: IconButton.styleFrom(
              foregroundColor: colorScheme.onSurface,
              backgroundColor: colorScheme.surface,
              padding: EdgeInsets.zero,
              minimumSize: const Size(40, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: const CircleBorder(),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _StatusBadge(
              colorScheme: colorScheme,
              status: event.status,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Hero Cover Image ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _EventHeroImage(
                imageUrl: artworkUrl,
                height: heroHeight + safeAreaTop,
              ),
            ),

            // ── Event info section ──────────────────────────────────────
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

            // ── Add tracks button ───────────────────────────────────────
            if (event.status != 'ENDED')
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: _AddTracksButton(
                    eventId: event.id,
                    colorScheme: colorScheme,
                  ),
                ),
              ),

            // ── Tracks section header ───────────────────────────────────
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

            // ── Tracks list ─────────────────────────────────────────────
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
                    );
                  },
                ),
              ),

            // Bottom padding to avoid overlap with sticky button
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),

      // ── Sticky bottom action ────────────────────────────────────
      bottomNavigationBar: event.status == 'ENDED'
          ? const _EventEndedBottomBar()
          : _StartEventBottomBar(eventId: event.id),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Status badge
// ────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.colorScheme,
    required this.status,
  });

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

class _EventEndedBottomBar extends StatelessWidget {
  const _EventEndedBottomBar();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.paddingOf(context).bottom + 16,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
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
            Text(
              'This event has ended',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Cover image
// ────────────────────────────────────────────────────────────────────────────

class _EventHeroImage extends StatelessWidget {
  const _EventHeroImage({
    required this.height,
    required this.imageUrl,
  });

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

// ────────────────────────────────────────────────────────────────────────────
// Event info section
// ────────────────────────────────────────────────────────────────────────────

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
      mainAxisSize: MainAxisSize.min,
      children: [
        // Event name
        Text(
          event.name,
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            fontSize: 26,
          ),
        ),

        const SizedBox(height: 10),

        // Visibility + Start date row
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

        // Description
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

        // Tags
        if (event.tags.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: event.tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
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

// ────────────────────────────────────────────────────────────────────────────
// Add Tracks button
// ────────────────────────────────────────────────────────────────────────────

class _AddTracksButton extends StatelessWidget {
  const _AddTracksButton({
    required this.eventId,
    required this.colorScheme,
  });

  final String eventId;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? colorScheme.primary.withValues(alpha: 0.15)
        : colorScheme.primary.withValues(alpha: 0.08);
    final borderColor = colorScheme.primary.withValues(alpha: 0.3);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showAddTracksSheet(context),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_rounded,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Add Tracks',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddTracksSheet(BuildContext context) {
    final musicVoteCubit = context.read<MusicVoteCubit>();

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        barrierColor: Colors.black.withValues(alpha: 0.7),
        backgroundColor: Colors.transparent,
        builder: (_) => BlocProvider(
          create: (_) => TrackSearchCubit(
            remoteDataSource: InjectionContainer().trackRemoteDataSource,
          ),
          child: _PreEventAddTrackSheet(
            eventId: eventId,
            musicVoteCubit: musicVoteCubit,
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Add Tracks search sheet (reuses DynamicSearchBottomSheet)
// ────────────────────────────────────────────────────────────────────────────

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
      onSearchChanged: (query) {
        context.read<TrackSearchCubit>().searchTracks(query);
      },
      content: BlocBuilder<TrackSearchCubit, TrackSearchState>(
        builder: (context, state) {
          if (state is TrackSearchLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is TrackSearchError) {
            return Center(
              child: Text(
                state.message,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.7),
                ),
              ),
            );
          }

          if (state is TrackSearchLoaded) {
            if (state.tracks.isEmpty) {
              return Center(
                child: Text(
                  'No results found.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: state.tracks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final track = state.tracks[index];
                return TrackSearchListTile(
                  track: track,
                  onAddTapped: (addedTrack) async {
                    await musicVoteCubit.addTrack(
                      eventId,
                      addedTrack.providerTrackId,
                    );
                  },
                );
              },
            );
          }

          // Initial state — prompt
          return Center(
            child: Text(
              'Start typing to search for tracks',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Pre-event track item (no voting — just displays order)
// ────────────────────────────────────────────────────────────────────────────

class _PreEventTrackItem extends StatelessWidget {
  const _PreEventTrackItem({
    required this.track,
    required this.rank,
    required this.colorScheme,
    required this.textTheme,
    required this.isDark,
  });

  final EventTrackModel track;
  final int rank;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E1E2E) : colorScheme.surface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.07),
        ),
      ),
      child: Row(
        children: [
          // Rank
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

          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: track.thumbnailUrl.isNotEmpty
                ? Image.network(
                    track.thumbnailUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _thumbnailFallback(),
                  )
                : _thumbnailFallback(),
          ),
          const SizedBox(width: 12),

          // Track info
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        '${track.artist} · ${track.formattedDuration}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 11,
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

          // Music note icon (no voting in pre-event)
          Icon(
            Icons.music_note_rounded,
            size: 20,
            color: colorScheme.onSurface.withValues(alpha: 0.25),
          ),
        ],
      ),
    );
  }

  Widget _thumbnailFallback() {
    return Container(
      width: 48,
      height: 48,
      color: colorScheme.primary.withValues(alpha: 0.2),
      child: Icon(
        Icons.music_note,
        size: 22,
        color: colorScheme.primary,
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Sticky Start Event bottom bar
// ────────────────────────────────────────────────────────────────────────────

class _StartEventBottomBar extends StatelessWidget {
  const _StartEventBottomBar({required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: BlocConsumer<MusicVoteCubit, MusicVoteState>(
            listenWhen: (prev, curr) =>
                prev.isStartingEvent &&
                !curr.isStartingEvent &&
                curr.error != null,
            listener: (context, state) {
              if (state.error != null) {
                AppSnackbar.showError(context, state.error!);
              }
            },
            buildWhen: (prev, curr) =>
                prev.isStartingEvent != curr.isStartingEvent,
            builder: (context, state) {
              return SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: state.isStartingEvent
                      ? null
                      : () => context.read<MusicVoteCubit>().startEvent(
                          eventId,
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: colorScheme.primary.withValues(
                      alpha: 0.5,
                    ),
                    disabledForegroundColor: Colors.white70,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    shadowColor: colorScheme.primary.withValues(alpha: 0.4),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: state.isStartingEvent
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                '🚀',
                                style: TextStyle(fontSize: 20),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Start Event',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
