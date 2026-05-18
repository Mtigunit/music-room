import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/auth/presentation/state/auth_state.dart';
import 'package:music_room/features/music_vote/data/models/event_detail_model.dart';
import 'package:music_room/features/music_vote/presentation/widgets/event_user_invite_bottom_sheet.dart';

class InviteUsersButton extends StatelessWidget {
  const InviteUsersButton({
    required this.event,
    required this.colorScheme,
    super.key,
  });

  final EventDetailModel event;
  final ColorScheme colorScheme;

  String? _currentUserId(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) return authState.user.id;
    if (authState is LoginSuccess) return authState.user.id;
    if (authState is RegisterSuccess) return authState.user.id;
    if (authState is GoogleLoginSuccess) return authState.user.id;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.white : Colors.black;
    final borderColor = isDark
        ? Colors.black.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.18);
    final foregroundColor = isDark ? Colors.black : Colors.white;

    return Semantics(
      button: true,
      label: 'Invite users',
      child: InkWell(
        onTap: () => _showInviteSheet(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_add_alt_1_outlined,
                size: 20,
                color: foregroundColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Invite',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: foregroundColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInviteSheet(BuildContext context) {
    final currentUserId = _currentUserId(context);

    if (event.id.isEmpty) {
      AppSnackbar.showInfo(context, 'Unable to invite: event context missing');
      return;
    }

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        barrierColor: Colors.black.withValues(alpha: 0.7),
        backgroundColor: Colors.transparent,
        builder: (_) => EventUserInviteBottomSheet(
          eventId: event.id,
          eventName: event.name,
          currentUserId: currentUserId,
        ),
      ),
    );
  }
}
