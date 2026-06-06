import 'dart:async';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/widgets/app_brand_icon.dart';
import 'package:music_room/core/widgets/top_toast.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/music_vote/data/models/event_detail_model.dart';
import 'package:music_room/features/music_vote/data/models/event_track_model.dart';
import 'package:music_room/features/music_vote/presentation/audio/room_audio_player.dart';
import 'package:music_room/features/music_vote/presentation/audio/stream_url_service.dart';
import 'package:music_room/features/music_vote/presentation/state/music_vote_cubit.dart';
import 'package:music_room/features/music_vote/presentation/widgets/live_header.dart';
import 'package:music_room/features/music_vote/presentation/widgets/player_card.dart';
import 'package:music_room/features/music_vote/presentation/widgets/queue_section.dart';
import 'package:music_room/features/music_vote/presentation/widgets/skeletons/music_vote_skeleton.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// The primary scrollable view for the Live Music Vote room.
///
/// Composes: [LiveHeader] → [PlayerCard] → [QueueSection].
/// Uses [BlocBuilder] to show loading / error / loaded states.
class MusicVoteView extends StatefulWidget {
  const MusicVoteView({
    super.key,
    this.eventId,
    this.isHost = false,
  });

  final String? eventId;
  final bool isHost;

  @override
  State<MusicVoteView> createState() => _MusicVoteViewState();
}

class _MusicVoteViewState extends State<MusicVoteView> {
  bool _showMiniPlayer = false;

  // ── Connectivity monitoring ──────────────────────────────────────────────
  late final StreamSubscription<List<ConnectivityResult>>
  _connectivitySubscription;
  bool _sheetIsOpen = false;

  // ── Audio phase listener ─────────────────────────────────────────────────
  StreamSubscription<AudioPlaybackPhase>? _phaseSub;
  bool _audioBootstrapped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<MusicVoteCubit>().state;
      final shouldKeepAwake =
          state.playbackStatus == 'PLAYING' && state.currentTrack != null;
      if (shouldKeepAwake) {
        unawaited(_setWakeLock(true));
      }
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
  }

  @override
  void dispose() {
    unawaited(_phaseSub?.cancel());
    unawaited(_connectivitySubscription.cancel());
    unawaited(_setWakeLock(false));
    super.dispose();
  }

  /// Subscribe to the [RoomAudioPlayer] phase stream.
  ///
  /// Called lazily on the first BlocListener trigger, once the
  /// [RoomAudioPlayer] has been provided in the widget tree.
  void _ensurePhaseSubscription(RoomAudioPlayer player) {
    if (_phaseSub != null) return;
    _phaseSub = player.phaseStream.listen(_onAudioPhaseChanged);
  }

  /// Reacts to actual audio engine phases, updating `isAudioLoading` in the
  /// cubit so the PlayerCard / MiniPlayer can gate progress + controls.
  void _onAudioPhaseChanged(AudioPlaybackPhase phase) {
    if (!mounted) return;
    final cubit = context.read<MusicVoteCubit>();

    switch (phase) {
      case AudioPlaybackPhase.loading:
        cubit.setAudioLoading(isLoading: true);
      case AudioPlaybackPhase.playing:
        cubit.setAudioLoading(isLoading: false);
      case AudioPlaybackPhase.paused:
        cubit.setAudioLoading(isLoading: false);
      case AudioPlaybackPhase.idle:
      case AudioPlaybackPhase.error:
        cubit.setAudioLoading(isLoading: false);
    }
  }

  /// Handles connectivity changes emitted by
  /// `Connectivity.onConnectivityChanged`.
  ///
  /// • On [ConnectivityResult.none] → shows a non-dismissible offline sheet.
  /// • On any other result          → closes the sheet and reloads the room.
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    if (!mounted) return;

    final isOffline = results.every(
      (r) => r == ConnectivityResult.none,
    );

    if (isOffline && !_sheetIsOpen) {
      _sheetIsOpen = true;
      unawaited(
        showModalBottomSheet<void>(
          context: context,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: Colors.transparent,
          builder: (_) => const _OfflineSheet(),
        ),
      );
    } else if (!isOffline && _sheetIsOpen) {
      _sheetIsOpen = false;
      if (!mounted) return;
      // Close the sheet that is on top of the navigator stack.
      Navigator.of(context, rootNavigator: true).pop();
      // Reload the room — loadRoom internally resets _hasJoinedLiveRoom and
      // re-joins the WebSocket session, so no extra call is needed.
      final eventId = widget.eventId;
      if (eventId != null && eventId.isNotEmpty) {
        unawaited(context.read<MusicVoteCubit>().loadRoom(eventId));
      }
    }
  }

  void _handleHeroVisibility(VisibilityInfo info) {
    if (!mounted) return;
    final shouldShow = info.visibleFraction < 0.1;
    if (shouldShow != _showMiniPlayer) {
      setState(() => _showMiniPlayer = shouldShow);
    }
  }

  Future<void> _setWakeLock(bool enabled) async {
    try {
      if (enabled) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } on Object {
      // Best-effort: if the platform channel is not available, skip.
    }
  }

  // ── Audio orchestration ─────────────────────────────────────────────────

  /// Drives the audio player in response to cubit state changes.
  ///
  /// **Critical flow:**
  /// 1. On track change or PLAYING: stop old audio immediately, emit loading,
  ///    then `await loadTrack`. The phase stream will emit `playing` only when
  ///    the audio engine is truly ready.
  /// 2. On PAUSED: preload but do not play.
  /// 3. On null track / status: stop.
  Future<void> _driveAudioPlayer(
    BuildContext context,
    MusicVoteState state,
  ) async {
    final player = context.read<RoomAudioPlayer>();
    _ensurePhaseSubscription(player);

    final track = state.currentTrack;
    final status = state.playbackStatus;

    // ── Nothing to play → stop ────────────────────────────────────────────
    if (track == null || status == null) {
      unawaited(player.stop());
      return;
    }

    // ── PLAYING → load and play ───────────────────────────────────────────
    if (status == 'PLAYING') {
      final startedAt = track.currentTrackStartedAt;
      final paused = track.pausedPlaybackPositionMs ?? 0;
      final startPositionMs = startedAt != null
          ? DateTime.now().difference(startedAt).inMilliseconds + paused
          : paused;

      // loadTrack internally:
      //  1. Stops old audio immediately (no overlap).
      //  2. Emits AudioPlaybackPhase.loading → phase listener sets
      //     isAudioLoading = true.
      //  3. Resolves URL + buffers.
      //  4. Emits AudioPlaybackPhase.playing → phase listener sets
      //     isAudioLoading = false.
      unawaited(player.loadTrack(track.providerTrackId, startPositionMs));
      return;
    }

    // ── PAUSED → preload but do not play ──────────────────────────────────
    if (status == 'PAUSED') {
      final resumePositionMs = track.pausedPlaybackPositionMs ?? 0;
      // loadTrack with autoPlay: false will resolve the URL, prepare the
      // player, seek to the correct position, and then emit paused.
      // It does NOT emit loading, so the user sees an interactive play button
      // immediately upon entering the room, while buffering happens silently.
      unawaited(
        player.loadTrack(
          track.providerTrackId,
          resumePositionMs,
          autoPlay: false,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<RoomAudioPlayer>(
      create: (context) => RoomAudioPlayer(
        streamUrlService: StreamUrlService(
          dio: InjectionContainer().apiClient.dio,
        ),
      ),
      dispose: (player) => player.dispose(),
      child: BlocListener<MusicVoteCubit, MusicVoteState>(
        listenWhen: (prev, curr) =>
            prev.error != curr.error ||
            prev.successMessage != curr.successMessage ||
            prev.playbackStatus != curr.playbackStatus ||
            prev.currentTrack?.id != curr.currentTrack?.id,
        listener: (context, state) {
          if (state.error != null && state.event != null) {
            TopToast.show(context, state.error!);
            context.read<MusicVoteCubit>().clearError();
          }

          if (state.successMessage != null && state.event != null) {
            TopToast.show(context, state.successMessage!, isError: false);
            context.read<MusicVoteCubit>().clearSuccessMessage();
          }

          final shouldKeepAwake =
              state.playbackStatus == 'PLAYING' && state.currentTrack != null;
          unawaited(_setWakeLock(shouldKeepAwake));

          // Drive the audio player — the real state will propagate back
          // through the phase stream → _onAudioPhaseChanged → cubit.
          unawaited(_driveAudioPlayer(context, state));
        },
        child: BlocBuilder<MusicVoteCubit, MusicVoteState>(
          builder: (context, state) {
            if (!_audioBootstrapped &&
                !state.isLoading &&
                state.event != null) {
              _audioBootstrapped = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                unawaited(_driveAudioPlayer(context, state));
              });
            }

            if (state.isLoading) {
              return const MusicVoteSkeleton();
            }

            if (state.error != null && state.event == null) {
              return _ErrorScaffold(
                eventId: widget.eventId,
                isHost: widget.isHost,
                message: state.error!,
                onRetry: widget.eventId != null && widget.eventId!.isNotEmpty
                    ? () => context.read<MusicVoteCubit>().loadRoom(
                        widget.eventId!,
                      )
                    : null,
              );
            }

            return _LoadedScaffold(
              eventId: widget.eventId,
              isHost: widget.isHost,
              showMiniPlayer: _showMiniPlayer,
              onHeroVisibility: _handleHeroVisibility,
              state: state,
            );
          },
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Offline sheet (non-dismissible)
// ────────────────────────────────────────────────────────────────────────────

class _OfflineSheet extends StatelessWidget {
  const _OfflineSheet();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.85),
              border: Border(
                top: BorderSide(
                  color: colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
            ),
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.paddingOf(context).bottom + 24,
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.error.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.wifi_off_rounded,
                    color: colorScheme.error,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 20),
                // Text
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connection Lost',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reconnecting to network...',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Loading
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadedScaffold extends StatelessWidget {
  const _LoadedScaffold({
    required this.eventId,
    required this.isHost,
    required this.showMiniPlayer,
    required this.onHeroVisibility,
    required this.state,
  });

  final String? eventId;
  final bool isHost;
  final bool showMiniPlayer;
  final ValueChanged<VisibilityInfo> onHeroVisibility;
  final MusicVoteState state;

  @override
  Widget build(BuildContext context) {
    final eventName = state.event?.name;
    final canVote =
        !(state.event?.policies.invitingOnly ?? false) ||
        (state.event?.isInvited ?? false) ||
        (state.event?.isHost ?? false);
    final isEnded = state.event?.status == 'ENDED';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F5FA),
      body: Stack(
        children: [
          SafeArea(
            top: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: VisibilityDetector(
                    key: ValueKey(
                      'music-vote-hero-${eventId ?? 'default'}',
                    ),
                    onVisibilityChanged: onHeroVisibility,
                    child: Stack(
                      children: [
                        PlayerCard(isHost: isHost),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: LiveHeader(
                            eventId: eventId,
                            eventName: eventName,
                            isHost: isHost,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF6F5FA),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(0, 20, 0, 24),
                    child: QueueSection(
                      tracks: state.tracks,
                      policies: state.event?.policies ?? const EventPolicies(),
                      eventId: eventId,
                      eventName: eventName,
                      isHost: isHost,
                      isEnded: isEnded,
                      canVote: canVote,
                      currentTrackId: state.currentTrack?.id,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: showMiniPlayer && state.currentTrack != null
                        ? 104
                        : 24,
                  ),
                ),
              ],
            ),
          ),
          if (showMiniPlayer && state.currentTrack != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _MiniPlayerBar(
                track: state.currentTrack!,
                isPlaying: state.playbackStatus == 'PLAYING',
                isAudioLoading: state.isAudioLoading,
                canControlPlayback:
                    isHost || (state.event?.isDelegated ?? false),
                isHost: isHost,
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  const _ErrorScaffold({
    required this.eventId,
    required this.isHost,
    required this.message,
    this.onRetry,
  });

  final String? eventId;
  final bool isHost;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0F14),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            LiveHeader(eventId: eventId, isHost: isHost),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF6F5FA),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: _ErrorBody(
                  message: message,
                  onRetry: onRetry,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Error body with retry button
// ────────────────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

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
              Icons.error_outline_rounded,
              size: 48,
              color: colorScheme.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniPlayerBar extends StatelessWidget {
  const _MiniPlayerBar({
    required this.track,
    required this.isPlaying,
    required this.isAudioLoading,
    required this.canControlPlayback,
    required this.isHost,
  });

  final EventTrackModel track;
  final bool isPlaying;

  /// `true` when audio is still buffering / resolving the stream URL.
  final bool isAudioLoading;

  /// `true` when the local user is the host or has accepted a delegation.
  final bool canControlPlayback;

  /// `true` when the local user is the primary event host.
  final bool isHost;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = colorScheme.primary;
    final controlsEnabled = canControlPlayback && !isAudioLoading;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF101018),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              _MiniArtwork(thumbnailUrl: track.thumbnailUrl, accent: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isAudioLoading && canControlPlayback)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: accent,
                    ),
                  ),
                )
              else
                _MiniControlButton(
                  icon: isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  accent: accent,
                  enabled: controlsEnabled,
                  onPressed: controlsEnabled
                      ? () async {
                          final cubit = context.read<MusicVoteCubit>();
                          if (isPlaying) {
                            cubit.pause();
                          } else {
                            final player = context.read<RoomAudioPlayer>();
                            if (player.loadedProviderTrackId !=
                                    track.providerTrackId &&
                                isHost) {
                              cubit.setAudioLoading(isLoading: true);
                              await player.loadTrack(
                                track.providerTrackId,
                                track.pausedPlaybackPositionMs ?? 0,
                                autoPlay: false,
                              );
                            }
                            cubit.play();
                          }
                        }
                      : null,
                ),
              const SizedBox(width: 6),
              const _MiniControlButton(
                icon: Icons.queue_music_rounded,
                accent: Colors.white,
                enabled: false,
                onPressed: null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniArtwork extends StatelessWidget {
  const _MiniArtwork({required this.thumbnailUrl, required this.accent});

  final String thumbnailUrl;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: thumbnailUrl.isNotEmpty
          ? Image.network(
              thumbnailUrl,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      width: 40,
      height: 40,
      color: accent.withValues(alpha: 0.2),
      child: const Center(child: AppBrandIcon(size: 20)),
    );
  }
}

class _MiniControlButton extends StatelessWidget {
  const _MiniControlButton({
    required this.icon,
    required this.accent,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final Color accent;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final resolvedOpacity = enabled ? 1.0 : 0.4;

    return Opacity(
      opacity: resolvedOpacity,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: enabled ? accent.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Icon(icon, color: accent, size: 18),
        ),
      ),
    );
  }
}
