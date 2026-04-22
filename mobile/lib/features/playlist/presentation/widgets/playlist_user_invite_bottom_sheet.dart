import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/app_back_button.dart';

class PlaylistUserInviteBottomSheet extends StatefulWidget {
  const PlaylistUserInviteBottomSheet({super.key});

  @override
  State<PlaylistUserInviteBottomSheet> createState() =>
      _PlaylistUserInviteBottomSheetState();
}

class _PlaylistUserInviteBottomSheetState
    extends State<PlaylistUserInviteBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  final Set<String> _invitedUsernames = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_MockInviteUser> get _allUsers => _mockInviteUsers;

  List<_MockInviteUser> get _friends {
    return _allUsers.where((user) => user.isFriend).toList(growable: false);
  }

  List<_MockInviteUser> get _filteredUsers {
    if (_query.isEmpty) {
      return _friends;
    }

    final query = _query.toLowerCase();
    return _allUsers
        .where((user) {
          return user.name.toLowerCase().contains(query) ||
              user.username.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  void _toggleInvite(_MockInviteUser user) {
    setState(() {
      if (_invitedUsernames.contains(user.username)) {
        _invitedUsernames.remove(user.username);
      } else {
        _invitedUsernames.add(user.username);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sheetBg = isDark ? const Color(0xFF151520) : colorScheme.surface;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    AppBackButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Invite Users',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                        Text(
                          'Start with friends, or search for anyone else',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _InviteSearchField(
                  controller: _searchController,
                  isDark: isDark,
                  colorScheme: colorScheme,
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _buildBody(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(ScrollController scrollController) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_query.isEmpty) {
      return ListView.separated(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        itemCount: _friends.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Your Friends',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  letterSpacing: 0.5,
                ),
              ),
            );
          }

          final friend = _friends[index - 1];
          return _InviteUserTile(
            user: friend,
            isInvited: _invitedUsernames.contains(friend.username),
            onInvitePressed: () => _toggleInvite(friend),
          );
        },
      );
    }

    final filtered = _filteredUsers;
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'No users found. Try another username or name.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: filtered.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Search Results',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                letterSpacing: 0.5,
              ),
            ),
          );
        }

        final user = filtered[index - 1];
        return _InviteUserTile(
          user: user,
          isInvited: _invitedUsernames.contains(user.username),
          onInvitePressed: () => _toggleInvite(user),
        );
      },
    );
  }
}

class _InviteSearchField extends StatelessWidget {
  const _InviteSearchField({
    required this.controller,
    required this.isDark,
    required this.colorScheme,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool isDark;
  final ColorScheme colorScheme;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final fieldBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);

    return Container(
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Icon(
              Icons.search,
              size: 20,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Name or username...',
                hintStyle: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.35),
                  fontSize: 15,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteUserTile extends StatelessWidget {
  const _InviteUserTile({
    required this.user,
    required this.isInvited,
    required this.onInvitePressed,
  });

  final _MockInviteUser user;
  final bool isInvited;
  final VoidCallback onInvitePressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final rowBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.02);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onInvitePressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: rowBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 52,
                  height: 52,
                  color: Color(user.colorHex),
                  child: Center(
                    child: Text(
                      user.initials,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user.isFriend) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Friend',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.username,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isInvited ? colorScheme.primary : colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    isInvited ? 'Invited' : 'Invite',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MockInviteUser {
  const _MockInviteUser({
    required this.name,
    required this.username,
    required this.colorHex,
    required this.isFriend,
  });

  final String name;
  final String username;
  final int colorHex;
  final bool isFriend;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

const List<_MockInviteUser> _mockInviteUsers = [
  _MockInviteUser(
    name: 'Sofia Martinez',
    username: '@sofia_m',
    colorHex: 0xFF9B59B6,
    isFriend: true,
  ),
  _MockInviteUser(
    name: 'Marcus Johnson',
    username: '@marcus_j',
    colorHex: 0xFF3498DB,
    isFriend: true,
  ),
  _MockInviteUser(
    name: 'Lena Schmidt',
    username: '@lena_s',
    colorHex: 0xFF2ECC71,
    isFriend: true,
  ),
  _MockInviteUser(
    name: 'Tom Williams',
    username: '@tomwill',
    colorHex: 0xFFE67E22,
    isFriend: true,
  ),
  _MockInviteUser(
    name: 'Aya Nakamura',
    username: '@aya_n',
    colorHex: 0xFFE74C8B,
    isFriend: true,
  ),
  _MockInviteUser(
    name: 'Nova Carter',
    username: '@novacarter',
    colorHex: 0xFF7C3AED,
    isFriend: false,
  ),
  _MockInviteUser(
    name: 'Kai Rivera',
    username: '@kai.r',
    colorHex: 0xFF1ABC9C,
    isFriend: false,
  ),
  _MockInviteUser(
    name: 'Mila Chen',
    username: '@milachen',
    colorHex: 0xFF34495E,
    isFriend: false,
  ),
  _MockInviteUser(
    name: 'Jordan Lee',
    username: '@jordy_lee',
    colorHex: 0xFFF39C12,
    isFriend: false,
  ),
  _MockInviteUser(
    name: 'Priya Patel',
    username: '@priya.p',
    colorHex: 0xFF8E44AD,
    isFriend: false,
  ),
  _MockInviteUser(
    name: 'Theo Brooks',
    username: '@theob',
    colorHex: 0xFF16A085,
    isFriend: false,
  ),
  _MockInviteUser(
    name: 'Samir Ali',
    username: '@samir.a',
    colorHex: 0xFFD35400,
    isFriend: false,
  ),
];
