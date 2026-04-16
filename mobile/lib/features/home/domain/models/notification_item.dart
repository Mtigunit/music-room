import 'package:flutter/material.dart';

enum NotificationType {
  invite,
  like,
  trending,
  system,
  follow,
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.timeAgo,
    required this.type,
    this.isUnread = false,
  });
  final String id;
  final String title;
  final String timeAgo;
  final bool isUnread;
  final NotificationType type;

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
