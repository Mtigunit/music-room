import 'package:music_room/features/home/domain/models/notification_item.dart';

const List<NotificationItem> mockNotifications = [
  NotificationItem(
    id: '1',
    title: 'DJ Marcus invited you to Friday Night Vibes',
    timeAgo: '2m ago',
    isUnread: true,
    type: NotificationType.invite,
  ),
  NotificationItem(
    id: '2',
    title: 'Alex liked your playlist "Summer Chill"',
    timeAgo: '1h ago',
    isUnread: true,
    type: NotificationType.like,
  ),
  NotificationItem(
    id: '3',
    title: 'New trending rooms near you',
    timeAgo: '5h ago',
    type: NotificationType.trending,
  ),
  NotificationItem(
    id: '4',
    title: 'Sarah started following you',
    timeAgo: 'Yesterday',
    type: NotificationType.follow,
  ),
  NotificationItem(
    id: '5',
    title: 'Your room "EDM Bangers" is gaining traction!',
    timeAgo: 'Yesterday',
    type: NotificationType.trending,
  ),
  NotificationItem(
    id: '6',
    title: 'Chris added a track to "Road Trip"',
    timeAgo: 'Yesterday',
    type: NotificationType.invite,
  ),
  NotificationItem(
    id: '7',
    title: 'System update scheduled for tomorrow',
    timeAgo: '2d ago',
    type: NotificationType.system,
  ),
  NotificationItem(
    id: '8',
    title: 'Emma liked your room',
    timeAgo: '2d ago',
    type: NotificationType.like,
  ),
  NotificationItem(
    id: '9',
    title: 'You reached 100 followers!',
    timeAgo: '3d ago',
    type: NotificationType.trending,
  ),
  NotificationItem(
    id: '10',
    title: 'Join the weekend listening party',
    timeAgo: '3d ago',
    type: NotificationType.invite,
  ),
  NotificationItem(
    id: '11',
    title: 'Liam liked your playlist "Workout"',
    timeAgo: '4d ago',
    type: NotificationType.like,
  ),
  NotificationItem(
    id: '12',
    title: 'New badges are available to collect',
    timeAgo: '4d ago',
    type: NotificationType.system,
  ),
  NotificationItem(
    id: '13',
    title: 'Mia started following you',
    timeAgo: '4d ago',
    type: NotificationType.follow,
  ),
  NotificationItem(
    id: '14',
    title: 'Your track suggestion was upvoted',
    timeAgo: '5d ago',
    type: NotificationType.like,
  ),
  NotificationItem(
    id: '15',
    title: 'Welcome to Music Room! Check out these tips.',
    timeAgo: '1w ago',
    type: NotificationType.system,
  ),
];
