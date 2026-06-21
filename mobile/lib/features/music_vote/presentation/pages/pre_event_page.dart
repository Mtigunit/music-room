import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/auth/presentation/state/auth_state.dart';
import 'package:music_room/features/music_vote/presentation/pages/guest_event_info_view.dart';
import 'package:music_room/features/music_vote/presentation/pages/host_event_info_view.dart';
import 'package:music_room/features/music_vote/presentation/state/music_vote_cubit.dart';
import 'package:music_room/features/music_vote/presentation/widgets/event_ended_overlay.dart';
import 'package:music_room/features/music_vote/presentation/widgets/music_vote_view.dart';
import 'package:music_room/features/music_vote/presentation/widgets/skeletons/pre_event_skeleton.dart';

/// Unified event page that handles the full lifecycle:
/// UPCOMING → shows Host/Guest info view
/// LIVE     → shows MusicVoteView (no route change, no cubit close)
/// ENDED    → shows EventEndedOverlay then navigates home
///
/// A single [MusicVoteCubit] lives for the entire session, so
/// socket listeners and room membership are never torn down by a
/// mid-session route transition.
class PreEventPage extends StatelessWidget {
  const PreEventPage({
    required this.eventId,
    super.key,
  });

  final String eventId;

  String? _currentUserId(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) return authState.user.id;
    if (authState is LoginSuccess) return authState.user.id;
    if (authState is RegisterSuccess) return authState.user.id;
    if (authState is GoogleLoginSuccess) return authState.user.id;
    return null;
  }

  bool _isHost(MusicVoteState state, String? userId) {
    final event = state.event;
    if (event == null) return false;
    return event.isHost || (userId == event.hostId);
  }

  @override
  Widget build(BuildContext context) {
    final userId = _currentUserId(context);

    return BlocProvider(
      create: (_) {
        final cubit = MusicVoteCubit(
          repository: InjectionContainer().musicVoteRepository,
          socketClient: InjectionContainer().socketClient,
          delegationGateway: InjectionContainer().delegationGateway,
          userId: userId,
        );
        unawaited(cubit.loadRoom(eventId));
        return cubit;
      },
      child: _PreEventBody(
        eventId: eventId,
        userId: userId,
        isHostFn: _isHost,
      ),
    );
  }
}

/// Separated into a StatefulWidget so we can track whether
/// the ended overlay has already been shown.
class _PreEventBody extends StatefulWidget {
  const _PreEventBody({
    required this.eventId,
    required this.userId,
    required this.isHostFn,
  });

  final String eventId;
  final String? userId;
  final bool Function(MusicVoteState, String?) isHostFn;

  @override
  State<_PreEventBody> createState() => _PreEventBodyState();
}

class _PreEventBodyState extends State<_PreEventBody> {
  bool _endedOverlayShown = false;

  void _showEndedOverlay(BuildContext context) {
    if (_endedOverlayShown) return;
    _endedOverlayShown = true;

    unawaited(
      showGeneralDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.8),
        pageBuilder: (ctx, animation, secondaryAnimation) => EventEndedOverlay(
          onFinished: () {
            if (ctx.mounted) {
              Navigator.of(ctx, rootNavigator: true).pop();
            }
            if (context.mounted) {
              context.go('/home');
            }
          },
        ),
      ),
    );
  }

  void _showHostStatusToast(
    BuildContext context, {
    required bool isDisconnected,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 6,
        content: Row(
          children: [
            Icon(
              isDisconnected
                  ? Icons.wifi_off_rounded
                  : Icons.check_circle_rounded,
              color: isDisconnected ? colorScheme.error : colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                isDisconnected
                    ? 'Host lost connection. '
                          'Waiting for them to return...'
                    : 'Host has reconnected! '
                          'The party continues.',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // ── Event ended ──────────────────────────────────
        BlocListener<MusicVoteCubit, MusicVoteState>(
          listenWhen: (prev, curr) =>
              prev.event?.status != 'ENDED' && curr.event?.status == 'ENDED',
          listener: (context, state) => _showEndedOverlay(context),
        ),
        // ── Host connection status (guests only) ─────────
        BlocListener<MusicVoteCubit, MusicVoteState>(
          listenWhen: (prev, curr) =>
              prev.hostConnectionStatus != curr.hostConnectionStatus,
          listener: (context, state) {
            final status = state.hostConnectionStatus;
            if (status != null && !widget.isHostFn(state, widget.userId)) {
              _showHostStatusToast(
                context,
                isDisconnected: status == HostConnectionStatus.disconnected,
              );
            }
          },
        ),
      ],
      child: BlocBuilder<MusicVoteCubit, MusicVoteState>(
        builder: (context, state) {
          // ── Loading / error ──────────────────────────
          if (state.isLoading || state.event == null) {
            if (state.error != null) {
              return Scaffold(
                appBar: AppBar(title: const Text('Error')),
                body: Center(child: Text(state.error!)),
              );
            }
            return const PreEventSkeleton();
          }

          final event = state.event!;
          final isHost = widget.isHostFn(state, widget.userId);

          // ── LIVE or ENDED → MusicVoteView ───────────
          if (event.status == 'LIVE' || event.status == 'ENDED') {
            return MusicVoteView(
              eventId: widget.eventId,
              isHost: isHost,
            );
          }

          // ── UPCOMING → info view ────────────────────
          if (isHost) {
            return HostEventInfoView(
              event: event,
              tracks: state.tracks,
            );
          } else {
            return GuestEventInfoView(
              event: event,
              tracks: state.tracks,
            );
          }
        },
      ),
    );
  }
}
