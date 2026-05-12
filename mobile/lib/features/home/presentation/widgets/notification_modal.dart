import 'package:flutter/material.dart';
import 'package:music_room/features/home/data/mock_data/mock_notifications.dart';
import 'package:music_room/features/home/domain/models/notification_item.dart';

extension NotificationItemIcon on NotificationItem {
  IconData get icon {
    switch (type) {
      case NotificationType.invite:
        return Icons.music_note;
      case NotificationType.like:
        return Icons.favorite;
      case NotificationType.trending:
        return Icons.trending_up;
      case NotificationType.system:
        return Icons.info_outline;
      case NotificationType.follow:
        return Icons.person_add;
    }
  }
}

class NotificationModal extends StatelessWidget {
  const NotificationModal({
    super.key,
    this.isPanel = false,
    this.onClose,
  });

  /// When `true`, renders as a desktop side panel (no drag handle, no top
  /// border radius, full height). When `false`, renders as a mobile bottom
  /// sheet with the existing styling.
  final bool isPanel;

  /// Optional callback to close the panel, used on desktop.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      constraints: isPanel
          ? null
          : BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
      decoration: BoxDecoration(
        color: isPanel ? Colors.transparent : colorScheme.surface,
        borderRadius: isPanel
            ? null
            : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: isPanel,
        child: Column(
          mainAxisSize: isPanel ? MainAxisSize.max : MainAxisSize.min,
          children: [
            // Drag Handle — bottom sheet only
            if (!isPanel) ...[
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (isPanel) const SizedBox(height: 20),
            // Title Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    'Notifications',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (isPanel && onClose != null) ...[
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: onClose,
                      tooltip: 'Close',
                    ),
                  ],
                ],
              ),
            ),
            const Divider(),
            // Notification List
            Flexible(
              child: ListView.builder(
                itemCount: mockNotifications.length,
                itemBuilder: (context, index) {
                  final notification = mockNotifications[index];
                  final isUnread = notification.isUnread;

                  return ColoredBox(
                    color: isUnread
                        ? colorScheme.primary.withValues(alpha: 0.05)
                        : Colors.transparent,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primaryContainer,
                        child: Icon(
                          notification.icon,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      title: Text(
                        notification.title,
                        style: TextStyle(
                          fontWeight: isUnread
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        notification.timeAgo,
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                      trailing: isUnread
                          ? Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
            if (!isPanel) const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
