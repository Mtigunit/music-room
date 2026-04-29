import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/music_vote/presentation/state/music_vote_cubit.dart';
import 'package:music_room/features/music_vote/presentation/widgets/event_ended_overlay.dart';
import 'package:music_room/features/music_vote/presentation/widgets/music_vote_view.dart';
import 'package:music_room/routes/route_names.dart';

/// Entry-point page for Guests in the "Live Event / Music Track Vote" feature.
///
/// Stripped down version of the host page, disables playback controls.
class GuestMusicVotePage extends StatelessWidget {
  const GuestMusicVotePage({
    super.key,
    this.eventId,
  });

  final String? eventId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = MusicVoteCubit(
          remoteDataSource: InjectionContainer().musicVoteRemoteDataSource,
          socketClient: InjectionContainer().socketClient,
          tokenStorageService: InjectionContainer().tokenStorageService,
        );
        final id = eventId;
        if (id != null && id.isNotEmpty) {
          unawaited(cubit.loadRoom(id));
        }
        return cubit;
      },
      child: MultiBlocListener(
        listeners: [
          BlocListener<MusicVoteCubit, MusicVoteState>(
            listenWhen: (prev, curr) =>
                prev.event?.status != 'ENDED' && curr.event?.status == 'ENDED',
            listener: (context, state) {
              unawaited(
                showGeneralDialog(
                  context: context,
                  barrierColor: Colors.black.withValues(alpha: 0.8),
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      EventEndedOverlay(
                        onFinished: () {
                          if (context.mounted) {
                            unawaited(
                              Navigator.of(context).pushReplacementNamed(
                                RouteNames.preEvent,
                                arguments: eventId,
                              ),
                            );
                          }
                        },
                      ),
                ),
              );
            },
          ),
          BlocListener<MusicVoteCubit, MusicVoteState>(
            listenWhen: (prev, curr) =>
                prev.hostConnectionStatus != curr.hostConnectionStatus,
            listener: (context, state) {
              final status = state.hostConnectionStatus;
              if (status != null) {
                _showHostStatusToast(
                  context,
                  isDisconnected: status == HostConnectionStatus.disconnected,
                );
              }
            },
          ),
        ],
        child: MusicVoteView(
          eventId: eventId,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: colorScheme.surface,
        elevation: 6,
        content: Row(
          children: [
            Icon(
              isDisconnected
                  ? Icons.wifi_off_rounded
                  : Icons.check_circle_rounded,
              color: isDisconnected ? Colors.orange : Colors.green,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                isDisconnected
                    ? 'Host lost connection. Waiting for them to return...'
                    : 'Host has reconnected! The party continues.',
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
}
