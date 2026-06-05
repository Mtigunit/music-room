import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room/core/widgets/app_back_button.dart';
import 'package:music_room/features/music_vote/presentation/state/music_vote_cubit.dart';
import 'package:music_room/features/music_vote/presentation/widgets/modals/delegation_bottom_sheet.dart';

/// The top header for the Live Room page.
///
/// Displays: back button · centered room title · single action icon.
///
/// The trailing action is contextual:
/// - **Host**: a settings icon that opens the delegation bottom sheet.
/// - **Guest**: a leave icon that opens the "leave event?" confirmation.
class LiveHeader extends StatelessWidget {
  const LiveHeader({
    super.key,
    this.eventId,
    this.eventName,
    this.isHost = false,
  });

  final String? eventId;
  final String? eventName;
  final bool isHost;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final roomTitle = _resolveRoomTitle(eventId, eventName);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: AppBackButton(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  color: Colors.white,
                  onPressed: () => context.pop(),
                ),
              ),
              Expanded(
                child: Text(
                  roomTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(
                width: 40,
                child: _HeaderActionButton(
                  icon: isHost ? Icons.settings_rounded : Icons.logout_rounded,
                  tooltip: isHost ? 'Room settings' : 'Leave room',
                  iconColor: isHost ? Colors.white : colorScheme.error,
                  onTap: isHost
                      ? () => _showDelegationSheet(context)
                      : () => _showLeaveConfirmation(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _resolveRoomTitle(String? roomId, String? name) {
    if (name != null && name.isNotEmpty) {
      return name;
    }

    if (roomId == null || roomId.isEmpty) {
      return 'Friday Night Vi...';
    }

    final shortId = roomId.length > 8 ? roomId.substring(0, 8) : roomId;
    return 'Room $shortId';
  }

  void _showDelegationSheet(BuildContext context) {
    if (eventId == null || eventId!.isEmpty) return;
    final resolvedEventId = eventId!;
    final cubit = context.read<MusicVoteCubit>();
    final event = cubit.state.event;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        barrierColor: Colors.black.withValues(alpha: 0.7),
        backgroundColor: Colors.transparent,
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: DelegationBottomSheet(
            eventId: resolvedEventId,
            eventName: event?.name ?? eventName,
            hostId: event?.hostId,
          ),
        ),
      ),
    );
  }

  void _showLeaveConfirmation(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Leave Event?'),
          content: const Text(
            'Are you sure you want to leave this room?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final cubit = context.read<MusicVoteCubit>();
                final eventId = this.eventId ?? cubit.state.event?.id;

                Navigator.pop(dialogContext); // Close dialog
                if (eventId != null) {
                  cubit.leaveEvent(eventId);
                }
                context.pop(); // Exit page
              },
              child: Text(
                'Leave',
                style: TextStyle(color: colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Single circular icon button used by [LiveHeader] for the trailing
/// action. Replaces the previous "more" popup menu so a single tap
/// triggers the contextual action directly.
class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.tooltip,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.15),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.8),
                width: 1.2,
              ),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
        ),
      ),
    );
  }
}
