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
}
