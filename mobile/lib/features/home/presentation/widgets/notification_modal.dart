import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room/core/models/notification_model.dart';
import 'package:music_room/core/services/notifications_service.dart';
import 'package:music_room/di/injection_container.dart';

/// Maps backend notification types to Flutter icons
extension NotificationTypeIcon on String {
  IconData get icon {
    switch (this) {
      case 'EVENT_INVITE':
        return Icons.event;
      case 'EVENT_START':
        return Icons.event_available;
      case 'FOLLOW':
        return Icons.person_add;
      default:
        return Icons.notifications_none;
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

  void _handleNotificationTap(
    BuildContext context,
    NotificationModel notification,
  ) {
    try {
      final payload = notification.payload;
      final id = payload['id'] as String?;

      if (id == null) return;

      // Mark as read immediately
      unawaited(
        InjectionContainer().notificationsService.markAsRead(notification.id),
      );

      // Close the modal/panel
      Navigator.of(context, rootNavigator: true).pop();

      if (notification.type == 'FOLLOW') {
        context.go('/profile/$id');
        return;
      }

      if (notification.type == 'EVENT_INVITE' ||
          notification.type == 'EVENT_START') {
        context.go('/events/$id');
      }
    } on Exception catch (_) {
      // ignore errors
    }
  }

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
              child: _NotificationListView(
                onNotificationTap: (notif) =>
                    _handleNotificationTap(context, notif),
              ),
            ),
            if (!isPanel) const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Stateful widget to manage real-time notification stream
class _NotificationListView extends StatefulWidget {
  const _NotificationListView({
    required this.onNotificationTap,
  });

  final void Function(NotificationModel) onNotificationTap;

  @override
  State<_NotificationListView> createState() => _NotificationListViewState();
}

class _NotificationListViewState extends State<_NotificationListView> {
  late NotificationsService _notificationsService;
  late Future<List<NotificationModel>> _initialFetch;
  final List<NotificationModel> _notifications = [];
  late StreamSubscription<NotificationModel> _incomingSubscription;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _notificationsService = InjectionContainer().notificationsService;
    // Always fetch fresh notifications when modal opens
    _initialFetch = _notificationsService.fetchNotifications();

    // Listen for real-time notifications
    _incomingSubscription = _notificationsService.incomingNotifications.listen(
      (notif) {
        if (mounted) {
          setState(() {
            // Check if notification already exists (avoid duplicates)
            if (!_notifications.any((n) => n.id == notif.id)) {
              _notifications.insert(0, notif);
            }
          });
        }
      },
    );
  }

  Future<void> _refreshNotifications() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    try {
      final fresh = await _notificationsService.fetchNotifications();
      if (mounted) {
        setState(() {
          // Update the initial fetch future
          _initialFetch = Future.value(fresh);
          // Clear and rebuild the list with fresh data and real-time
          // notifications
          _notifications.clear();
        });
      }
    } on Exception catch (_) {
      // Error handled by FutureBuilder
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  void dispose() {
    unawaited(_incomingSubscription.cancel());
    super.dispose();
  }

  String _formatTimeAgo(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  String? _getMetaLabel(
    String notificationType,
    Map<String, dynamic>? meta,
  ) {
    if (meta == null) return null;

    if (notificationType == 'EVENT_INVITE' ||
        notificationType == 'EVENT_START') {
      final eventName = meta['eventName'] as String?;
      if (eventName != null && eventName.isNotEmpty) {
        return '📍 $eventName';
      }
    }

    if (notificationType == 'FOLLOW') {
      // Could show username from meta if available
      final userName = meta['userName'] as String?;
      if (userName != null && userName.isNotEmpty) {
        return '👤 $userName';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<NotificationModel>>(
      future: _initialFetch,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load notifications',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _initialFetch = _notificationsService
                            .fetchNotifications();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final allNotifications = [
          ..._notifications,
          ...?snapshot.data?.where(
            (n) => !_notifications.any((existing) => existing.id == n.id),
          ),
        ];

        if (allNotifications.isEmpty) {
          // RefreshIndicator requires a scrollable child. Provide an
          // always-scrollable ListView so pull-to-refresh works on empty state.
          return RefreshIndicator(
            onRefresh: _refreshNotifications,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 48,
                          color: colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No notifications yet',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshNotifications,
          child: ListView.builder(
            itemCount: allNotifications.length,
            physics: const AlwaysScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final notification = allNotifications[index];
              final meta =
                  notification.payload['meta'] as Map<String, dynamic>?;
              final metaLabel = _getMetaLabel(notification.type, meta);

              return ColoredBox(
                color: !notification.isRead
                    ? colorScheme.primary.withValues(alpha: 0.05)
                    : Colors.transparent,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: () => widget.onNotificationTap(notification),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: colorScheme.onSurface.withValues(
                              alpha: 0.08,
                            ),
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar
                          Padding(
                            padding: const EdgeInsets.only(right: 12, top: 4),
                            child: CircleAvatar(
                              backgroundColor: colorScheme.primaryContainer,
                              radius: 24,
                              child: Icon(
                                notification.type.icon,
                                color: colorScheme.onPrimaryContainer,
                                size: 22,
                              ),
                            ),
                          ),
                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title with unread indicator
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        notification.title,
                                        style: TextStyle(
                                          fontWeight: !notification.isRead
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                          fontSize: 14,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    if (!notification.isRead)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: colorScheme.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // Message (if available)
                                if (notification.message != null &&
                                    notification.message!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      notification.message!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colorScheme.onSurface.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                // Meta info (event name, etc.)
                                if (metaLabel != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.secondary.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        metaLabel,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme.secondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                // Timestamp
                                Text(
                                  _formatTimeAgo(notification.createdAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurface.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
