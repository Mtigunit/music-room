import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/invite_bottom_sheet.dart';

class PlaylistUserInviteBottomSheet extends StatelessWidget {
  const PlaylistUserInviteBottomSheet({
    required this.playlistId,
    required this.playlistName,
    super.key,
  });

  final String playlistId;
  final String playlistName;

  @override
  Widget build(BuildContext context) {
    final friends = _mockInviteUsers
        .map(
          (user) => InviteFriendData(
            id: user.username,
            name: user.name,
            username: user.username,
            colorHex: user.colorHex,
            isInvited: user.isInvited,
          ),
        )
        .toList(growable: false);

    return InviteBottomSheet(
      eventId: playlistId,
      shareLink: 'musicroom.app/playlist/$playlistId',
      title: 'Invite Users',
      subtitle: 'Share "$playlistName" with your friends',
      friends: friends,
    );
  }
}

class _MockInviteUser {
  const _MockInviteUser({
    required this.name,
    required this.username,
    required this.colorHex,
    required this.isInvited,
  });

  final String name;
  final String username;
  final int colorHex;
  final bool isInvited;
}

const List<_MockInviteUser> _mockInviteUsers = [
  _MockInviteUser(
    name: 'Sofia Martinez',
    username: '@sofia_m',
    colorHex: 0xFF9B59B6,
    isInvited: false,
  ),
  _MockInviteUser(
    name: 'Marcus Johnson',
    username: '@marcus_j',
    colorHex: 0xFF3498DB,
    isInvited: false,
  ),
  _MockInviteUser(
    name: 'Lena Schmidt',
    username: '@lena_s',
    colorHex: 0xFF2ECC71,
    isInvited: true,
  ),
  _MockInviteUser(
    name: 'Tom Williams',
    username: '@tomwill',
    colorHex: 0xFFE67E22,
    isInvited: false,
  ),
  _MockInviteUser(
    name: 'Aya Nakamura',
    username: '@aya_n',
    colorHex: 0xFFE74C8B,
    isInvited: true,
  ),
];
