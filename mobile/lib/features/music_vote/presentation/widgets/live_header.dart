import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/widgets/app_back_button.dart';
import 'package:music_room/core/widgets/invite_bottom_sheet.dart';
import 'package:music_room/features/music_vote/presentation/state/music_vote_cubit.dart';
import 'package:music_room/features/music_vote/presentation/widgets/modals/delegation_bottom_sheet.dart';

/// The top header for the Live Room page.
///
/// Displays: back button · centered room title · menu button.
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
              const SizedBox(
                width: 40,
                child: AppBackButton(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  color: Colors.white,
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
                child: _HeaderMenuButton(
                  isHost: isHost,
                  colorScheme: colorScheme,
                  onInvite: () => _showInviteSheet(context),
                  onManage: () => _showManageRoomSheet(context),
                  onLeave: () => _showLeaveConfirmation(context),
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

  void _showInviteSheet(BuildContext context) {
    final resolvedEventId = (eventId != null && eventId!.isNotEmpty)
        ? eventId!
        : 'room-1';
    final shareLink = 'musicroom.app/join/$resolvedEventId';
    final friends = <InviteFriendData>[];

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        barrierColor: Colors.black.withValues(alpha: 0.7),
        backgroundColor: Colors.transparent,
        builder: (_) => InviteBottomSheet(
          eventId: resolvedEventId,
          shareLink: shareLink,
          friends: friends,
          onCopyLink: () {},
          onShareTapped: (action) {},
          onFriendInviteChanged: (change) {},
        ),
      ),
    );
  }

  void _showManageRoomSheet(BuildContext context) {
    if (eventId == null || eventId!.isEmpty) return;
    final resolvedEventId = eventId!;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        barrierColor: Colors.black.withValues(alpha: 0.7),
        backgroundColor: Colors.transparent,
        builder: (_) => BlocProvider.value(
          value: context.read<MusicVoteCubit>(),
          child: DelegationBottomSheet(eventId: resolvedEventId),
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
                Navigator.pop(context); // Exit page
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

enum _HeaderMenuAction { invite, manage, leave }

class _HeaderMenuButton extends StatelessWidget {
  const _HeaderMenuButton({
    required this.isHost,
    required this.colorScheme,
    required this.onInvite,
    required this.onManage,
    required this.onLeave,
  });

  final bool isHost;
  final ColorScheme colorScheme;
  final VoidCallback onInvite;
  final VoidCallback onManage;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final entries = <PopupMenuEntry<_HeaderMenuAction>>[];
    if (isHost) {
      entries
        ..add(
          const PopupMenuItem(
            value: _HeaderMenuAction.invite,
            child: Text('Invite guests'),
          ),
        )
        ..add(
          const PopupMenuItem(
            value: _HeaderMenuAction.manage,
            child: Text('Manage room'),
          ),
        );
    } else {
      entries.add(
        PopupMenuItem(
          value: _HeaderMenuAction.leave,
          textStyle: TextStyle(color: colorScheme.error),
          child: const Text('Leave room'),
        ),
      );
    }

    return PopupMenuButton<_HeaderMenuAction>(
      tooltip: 'Room options',
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (action) {
        switch (action) {
          case _HeaderMenuAction.invite:
            onInvite();
            return;
          case _HeaderMenuAction.manage:
            onManage();
            return;
          case _HeaderMenuAction.leave:
            onLeave();
            return;
        }
      },
      itemBuilder: (context) => entries,
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
        child: const Icon(
          Icons.more_horiz,
          size: 18,
          color: Colors.white,
        ),
      ),
    );
  }
}
