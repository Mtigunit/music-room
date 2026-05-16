import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/core/widgets/invite_bottom_sheet.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/music_vote/domain/repositories/music_vote_repository.dart';
import 'package:music_room/features/search/data/datasources/search_remote_datasource.dart';

class EventUserInviteBottomSheet extends StatefulWidget {
  const EventUserInviteBottomSheet({
    required this.eventId,
    required this.eventName,
    this.currentUserId,
    this.initialInvitedIds = const <String>[],
    super.key,
  });

  final String eventId;
  final String eventName;
  final String? currentUserId;
  final List<String> initialInvitedIds;

  @override
  State<EventUserInviteBottomSheet> createState() =>
      _EventUserInviteBottomSheetState();
}

class _EventUserInviteBottomSheetState
    extends State<EventUserInviteBottomSheet> {
  late final MusicVoteRepository _musicVoteRepository;
  late final ISearchRemoteDataSource _searchDataSource;
  late final Set<String> _invitedUserIds;

  @override
  void initState() {
    super.initState();
    final container = InjectionContainer();
    _musicVoteRepository = container.musicVoteRepository;
    _searchDataSource = container.searchRemoteDataSource;
    _invitedUserIds = widget.initialInvitedIds.toSet();
  }

  @override
  Widget build(BuildContext context) {
    return InviteBottomSheet(
      eventId: widget.eventId,
      shareLink: 'musicroom.app/join/${widget.eventId}',
      subtitle: 'Share "${widget.eventName}" with your friends',
      friends: const <InviteFriendData>[],
      onSearchUsers: _searchUsers,
      onInviteAction: _inviteUser,
    );
  }

  Future<List<InviteFriendData>> _searchUsers(String query) async {
    final results = await _searchDataSource.searchUsers(query);
    return results
        .where(
          (user) =>
              user.id.trim().isNotEmpty && user.id != widget.currentUserId,
        )
        .map(
          (user) => InviteFriendData(
            id: user.id,
            name: user.username,
            username: '@${user.username}',
            colorHex: _colorFromSeed(user.id),
            avatarUrl: user.avatarUrl,
            isInvited: _invitedUserIds.contains(user.id),
          ),
        )
        .toList(growable: false);
  }

  Future<bool> _inviteUser(
    InviteFriendData friend, {
    required bool isCurrentlyInvited,
  }) async {
    if (isCurrentlyInvited || _invitedUserIds.contains(friend.id)) {
      AppSnackbar.showInfo(
        context,
        '${friend.name} is already invited.',
      );
      return true;
    }

    try {
      await _musicVoteRepository.inviteUserToEvent(
        widget.eventId,
        friend.id,
      );
      _invitedUserIds.add(friend.id);
      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          'Invitation sent to ${friend.name}.',
        );
      }
      return true;
    } on DioException catch (error) {
      if (mounted) {
        AppSnackbar.showError(context, _inviteErrorMessage(error));
      }
      return false;
    } on Object {
      if (mounted) {
        AppSnackbar.showError(
          context,
          'Could not send invitation. Please try again.',
        );
      }
      return false;
    }
  }

  String _inviteErrorMessage(DioException error) {
    final statusCode = error.response?.statusCode;
    final apiMessage = _extractApiMessage(error.response?.data);
    if (apiMessage != null && apiMessage.isNotEmpty) {
      return apiMessage;
    }

    switch (statusCode) {
      case 400:
        return 'This user could not be invited. Please check and try again.';
      case 401:
        return 'Your session expired. Please sign in again.';
      case 403:
        return 'Only the host can invite friends to this event.';
      case 404:
        return 'Event or user not found.';
      case 409:
        return 'This user is already invited or a member of the event.';
      default:
        if (error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.sendTimeout) {
          return 'Network issue while sending invite. Please try again.';
        }
        return 'Could not send invitation. Please try again.';
    }
  }

  String? _extractApiMessage(Object? data) {
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
      if (message is List<dynamic>) {
        final joined = message
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .join('\n');
        if (joined.isNotEmpty) {
          return joined;
        }
      }
    }
    return null;
  }

  int _colorFromSeed(String seed) {
    final hash = _stableHash(seed);
    final red = 100 + (hash & 0x3F);
    final green = 100 + ((hash >> 8) & 0x3F);
    final blue = 100 + ((hash >> 16) & 0x3F);
    return 0xFF000000 | (red << 16) | (green << 8) | blue;
  }

  int _stableHash(String input) {
    const fnvPrime = 0x01000193;
    var hash = 0x811C9DC5;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash;
  }
}
