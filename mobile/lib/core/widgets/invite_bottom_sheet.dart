import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InviteFriendData {
  const InviteFriendData({
    required this.id,
    required this.name,
    required this.username,
    required this.colorHex,
    this.isInvited = false,
  });

  final String id;
  final String name;
  final String username;
  final int colorHex;
  final bool isInvited;
}

class InviteShareAction {
  const InviteShareAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;
}

class InviteFriendInviteChange {
  const InviteFriendInviteChange({
    required this.friend,
    required this.isInvited,
  });

  final InviteFriendData friend;
  final bool isInvited;
}

/// Reusable invite sheet with share link, social actions, and friends list.
///
/// This widget is feature-agnostic and receives all runtime data via
/// constructor parameters.
class InviteBottomSheet extends StatefulWidget {
  const InviteBottomSheet({
    required this.eventId,
    required this.shareLink,
    required this.friends,
    this.title = 'Invite Friends',
    this.subtitle = 'Share this room with your friends',
    this.socialActions,
    this.onCopyLink,
    this.onShareTapped,
    this.onFriendInviteChanged,
    this.onClosePressed,
    super.key,
  });

  final String eventId;
  final String shareLink;
  final List<InviteFriendData> friends;

  final String title;
  final String subtitle;

  final List<InviteShareAction>? socialActions;
  final VoidCallback? onCopyLink;
  final ValueChanged<InviteShareAction>? onShareTapped;
  final ValueChanged<InviteFriendInviteChange>? onFriendInviteChanged;
  final VoidCallback? onClosePressed;

  static const List<InviteShareAction> _defaultSocialActions = [
    InviteShareAction(
      id: 'whatsapp',
      label: 'WhatsApp',
      icon: Icons.chat_bubble_outline,
      color: Color(0xFF25D366),
    ),
    InviteShareAction(
      id: 'instagram',
      label: 'Instagram',
      icon: Icons.camera_alt_outlined,
      color: Color(0xFFE1306C),
    ),
    InviteShareAction(
      id: 'twitter',
      label: 'Twitter',
      icon: Icons.close,
      color: Color(0xFF1DA1F2),
    ),
    InviteShareAction(
      id: 'copy',
      label: 'Copy Link',
      icon: Icons.link_rounded,
      color: Color(0xFF7A7A7A),
    ),
  ];

  @override
  State<InviteBottomSheet> createState() => _InviteBottomSheetState();
}

class _InviteBottomSheetState extends State<InviteBottomSheet> {
  String _searchQuery = '';

  List<InviteFriendData> get _displayUsers {
    if (_searchQuery.trim().isEmpty) {
      return widget.friends;
    }

    final query = _searchQuery.toLowerCase();
    final filteredFriends = widget.friends.where((f) {
      return f.name.toLowerCase().contains(query) ||
          f.username.toLowerCase().contains(query);
    }).toList();

    // Mock global search results for demonstration
    final mockUsers = [
      InviteFriendData(
        id: 'mock1',
        name: 'Global $_searchQuery',
        username: '@global_${_searchQuery.replaceAll(' ', '')}',
        colorHex: 0xFF9C27B0,
      ),
      InviteFriendData(
        id: 'mock2',
        name: '$_searchQuery User',
        username: '@user_${_searchQuery.replaceAll(' ', '')}',
        colorHex: 0xFFE91E63,
      ),
    ];

    return [...filteredFriends, ...mockUsers];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;

    final sheetBg = isDark ? const Color(0xFF1A1A27) : colorScheme.surface;
    final resolvedActions =
        widget.socialActions ?? InviteBottomSheet._defaultSocialActions;
    final displayList = _displayUsers;

    return Container(
      height: screenSize.height * 0.9,
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        widget.onClosePressed ??
                        () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.onSurface.withValues(
                        alpha: 0.06,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Compact Social Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _SocialShareRow(
                link: widget.shareLink,
                actions: resolvedActions,
                colorScheme: colorScheme,
                isDark: isDark,
                onCopy: widget.onCopyLink,
                onShareTapped: widget.onShareTapped,
              ),
            ),
            const SizedBox(height: 24),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search friends or username...',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: theme.colorScheme.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // List Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _searchQuery.isEmpty ? 'Your Friends' : 'Search Results',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // User List
            Expanded(
              child: displayList.isEmpty
                  ? Center(
                      child: Text(
                        'No results found.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: displayList.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final friend = displayList[index];
                        return _FriendInviteItem(
                          friend: friend,
                          colorScheme: colorScheme,
                          isDark: isDark,
                          onInviteChanged: (isInvited) {
                            widget.onFriendInviteChanged?.call(
                              InviteFriendInviteChange(
                                friend: friend,
                                isInvited: isInvited,
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialShareRow extends StatelessWidget {
  const _SocialShareRow({
    required this.link,
    required this.actions,
    required this.colorScheme,
    required this.isDark,
    required this.onCopy,
    required this.onShareTapped,
  });

  final String link;
  final List<InviteShareAction> actions;
  final ColorScheme colorScheme;
  final bool isDark;
  final VoidCallback? onCopy;
  final ValueChanged<InviteShareAction>? onShareTapped;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final btnBg = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.05);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: actions
            .map((action) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Semantics(
                  button: true,
                  label: 'Share via ${action.label}',
                  child: GestureDetector(
                    onTap: () async {
                      if (action.id == 'copy') {
                        await Clipboard.setData(ClipboardData(text: link));
                        onCopy?.call();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Link copied to clipboard'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      }

                      onShareTapped?.call(action);
                      if (kDebugMode) {
                        debugPrint('Share via ${action.label}');
                      }
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: btnBg,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.08,
                              ),
                            ),
                          ),
                          child: Icon(
                            action.icon,
                            size: 24,
                            color: action.color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          action.label,
                          style: textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: colorScheme.onSurface.withValues(
                              alpha: 0.65,
                            ),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _FriendInviteItem extends StatefulWidget {
  const _FriendInviteItem({
    required this.friend,
    required this.colorScheme,
    required this.isDark,
    required this.onInviteChanged,
  });

  final InviteFriendData friend;
  final ColorScheme colorScheme;
  final bool isDark;
  final ValueChanged<bool> onInviteChanged;

  @override
  State<_FriendInviteItem> createState() => _FriendInviteItemState();
}

class _FriendInviteItemState extends State<_FriendInviteItem> {
  late bool _invited;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _invited = widget.friend.isInvited;
  }

  Future<void> _toggleInvite() async {
    if (_isLoading) return;

    if (!_invited) {
      if (mounted) setState(() => _isLoading = true);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _invited = true;
      });
    } else {
      setState(() => _invited = false);
    }

    widget.onInviteChanged(_invited);
    if (kDebugMode) {
      debugPrint('Invited: ${widget.friend.name}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rowBg = widget.isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.02);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(widget.friend.colorHex),
            ),
            child: Center(
              child: Text(
                widget.friend.name[0],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
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
                Text(
                  widget.friend.name,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.friend.username,
                  style: textTheme.bodySmall?.copyWith(
                    color: widget.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: _invited
                ? 'Cancel invitation'
                : 'Invite ${widget.friend.name}',
            child: GestureDetector(
              onTap: _toggleInvite,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _isLoading || _invited
                      ? widget.colorScheme.primary.withValues(alpha: 0.15)
                      : widget.colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                  border: _isLoading || _invited
                      ? Border.all(
                          color: widget.colorScheme.primary.withValues(
                            alpha: 0.4,
                          ),
                        )
                      : null,
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: widget.colorScheme.primary,
                        ),
                      )
                    : Text(
                        _invited ? 'Invited ✓' : 'Invite',
                        style: TextStyle(
                          color: _invited
                              ? widget.colorScheme.primary
                              : Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
