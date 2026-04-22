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
class InviteBottomSheet extends StatelessWidget {
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
      label: 'Copy',
      icon: Icons.link_rounded,
      color: Color(0xFF7A7A7A),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sheetBg = isDark ? const Color(0xFF1A1A27) : colorScheme.surface;
    final resolvedActions = socialActions ?? _defaultSocialActions;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.9,
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
              const SizedBox(height: 16),

              // Header with title/subtitle and close action.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed:
                          onClosePressed ?? () => Navigator.of(context).pop(),
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
              const SizedBox(height: 18),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _RoomLinkBox(
                  eventId: eventId,
                  link: shareLink,
                  colorScheme: colorScheme,
                  isDark: isDark,
                  onCopy: onCopyLink,
                ),
              ),
              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SocialShareRow(
                  link: shareLink,
                  actions: resolvedActions,
                  colorScheme: colorScheme,
                  isDark: isDark,
                  onCopy: onCopyLink,
                  onShareTapped: onShareTapped,
                ),
              ),
              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Your Friends',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: friends.isEmpty
                    ? Center(
                        child: Text(
                          'No friends available to invite yet.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: friends.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final friend = friends[index];
                          return _FriendInviteItem(
                            friend: friend,
                            colorScheme: colorScheme,
                            isDark: isDark,
                            onInviteChanged: (isInvited) {
                              onFriendInviteChanged?.call(
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

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class _RoomLinkBox extends StatefulWidget {
  const _RoomLinkBox({
    required this.eventId,
    required this.link,
    required this.colorScheme,
    required this.isDark,
    required this.onCopy,
  });

  final String eventId;
  final String link;
  final ColorScheme colorScheme;
  final bool isDark;
  final VoidCallback? onCopy;

  @override
  State<_RoomLinkBox> createState() => _RoomLinkBoxState();
}

class _RoomLinkBoxState extends State<_RoomLinkBox> {
  Timer? _copyTimer;
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.link));
    widget.onCopy?.call();
    _copyTimer?.cancel();
    setState(() => _copied = true);
    _copyTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final boxBg = widget.isDark
        ? widget.colorScheme.primary.withValues(alpha: 0.12)
        : widget.colorScheme.primary.withValues(alpha: 0.06);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      decoration: BoxDecoration(
        color: boxBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Room Link',
                  style: textTheme.bodySmall?.copyWith(
                    color: widget.colorScheme.onSurface.withValues(alpha: 0.45),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.link,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Event: ${widget.eventId}',
                  style: textTheme.labelSmall?.copyWith(
                    color: widget.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            button: true,
            label: 'Copy room link',
            child: GestureDetector(
              onTap: _copy,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: _copied ? Colors.green : widget.colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _copied ? 'Copied!' : 'Copy',
                  style: const TextStyle(
                    color: Colors.white,
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions
          .map((action) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
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
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: btnBg,
                            borderRadius: BorderRadius.circular(14),
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
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      action.label,
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          })
          .toList(growable: false),
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

  @override
  void initState() {
    super.initState();
    _invited = widget.friend.isInvited;
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
                ),
                Text(
                  widget.friend.username,
                  style: textTheme.bodySmall?.copyWith(
                    color: widget.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: _invited
                ? 'Cancel invitation'
                : 'Invite ${widget.friend.name}',
            child: GestureDetector(
              onTap: () {
                setState(() => _invited = !_invited);
                widget.onInviteChanged(_invited);
                if (kDebugMode) {
                  debugPrint('Invited: ${widget.friend.name}');
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _invited
                      ? widget.colorScheme.primary.withValues(alpha: 0.15)
                      : widget.colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                  border: _invited
                      ? Border.all(
                          color: widget.colorScheme.primary.withValues(
                            alpha: 0.4,
                          ),
                        )
                      : null,
                ),
                child: Text(
                  _invited ? 'Invited ✓' : 'Invite',
                  style: TextStyle(
                    color: _invited ? widget.colorScheme.primary : Colors.white,
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
