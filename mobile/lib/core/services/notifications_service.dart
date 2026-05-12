import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:music_room/core/models/notification_model.dart';
import 'package:music_room/core/network/api_client.dart';
import 'package:music_room/core/realtime/socket_client.dart';
import 'package:music_room/core/realtime/socket_events.dart';

/// Lightweight notifications service: fetch history, mark read, and
/// real-time stream
class NotificationsService {
  NotificationsService({required this.apiClient, required this.socketClient});

  final ApiClient apiClient;
  final SocketClient socketClient;

  final StreamController<NotificationModel> _incomingController =
      StreamController<NotificationModel>.broadcast();
  final StreamController<int> _unreadCountController =
      StreamController<int>.broadcast();

  Stream<NotificationModel> get incomingNotifications =>
      _incomingController.stream;

  Stream<int> get unreadCountStream => _unreadCountController.stream;

  int get unreadCount => _unreadCount;

  int _unreadCount = 0;
  List<NotificationModel>? _cachedNotifications;
  DateTime? _lastFetchTime;

  Future<void> init() async {
    // No-op for now; remain available via InjectionContainer
  }

  Future<List<NotificationModel>> fetchNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await apiClient.get<Map<String, dynamic>>(
        '/notifications',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );
      final data = response.data ?? <String, dynamic>{};
      final list = (data['data'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final notifications = list.map(NotificationModel.fromJson).toList();

      // Cache the notifications and timestamp
      _cachedNotifications = notifications;
      _lastFetchTime = DateTime.now();

      // update unread count from items
      _updateUnreadFromList(list);

      if (kDebugMode) {
        debugPrint(
          '📥 [NotificationsService] Fetched ${notifications.length} '
          'notifications',
        );
      }

      return notifications;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '❌ [NotificationsService] Error fetching notifications: $e',
        );
      }
      rethrow;
    }
  }

  Future<NotificationModel> markAsRead(String id) async {
    final wasUnread = _isCachedNotificationUnread(id);
    try {
      final response = await apiClient.patch<Map<String, dynamic>>(
        '/notifications/$id/read',
      );
      final data = response.data ?? <String, dynamic>{};
      final notification = NotificationModel.fromJson(
        data['data'] as Map<String, dynamic>,
      );
      _replaceCachedNotification(notification.copyWithRead(isRead: true));
      if (wasUnread && notification.isRead) {
        _decrementUnread();
      }
      if (kDebugMode) {
        debugPrint(
          '✅ [NotificationsService] Marked notification as read: $id',
        );
      }
      return notification;
    } on Exception catch (e) {
      if (kDebugMode) {
        debugPrint(
          '❌ [NotificationsService] Error marking notification as read: $e',
        );
      }
      rethrow;
    }
  }

  void attachSocketListeners() {
    socketClient.on(
      SocketEvent.notificationNew.value,
      _handleSocketNotification,
    );
  }

  void detachSocketListeners() {
    socketClient.off(SocketEvent.notificationNew.value);
  }

  void _handleSocketNotification(dynamic payload) {
    try {
      if (payload is Map<String, dynamic>) {
        final notif = NotificationModel.fromJson(payload);
        _replaceCachedNotification(notif);
        _incomingController.add(notif);
        _incrementUnread();
        if (kDebugMode) {
          debugPrint(
            '📬 [NotificationsService] Received notification: '
            '${notif.type} - ${notif.title}',
          );
        }
      }
    } on Exception catch (e) {
      if (kDebugMode) {
        debugPrint(
          '❌ [NotificationsService] Error parsing socket '
          'notification: $e',
        );
      }
    }
  }

  void _updateUnreadFromList(List<Map<String, dynamic>> list) {
    final count = list.where((e) => !(e['isRead'] as bool? ?? false)).length;
    _unreadCount = count;
    _unreadCountController.add(_unreadCount);
  }

  void _incrementUnread() {
    _unreadCount += 1;
    _unreadCountController.add(_unreadCount);
  }

  void _decrementUnread() {
    if (_unreadCount > 0) {
      _unreadCount -= 1;
      _unreadCountController.add(_unreadCount);
    }
  }

  bool _isCachedNotificationUnread(String id) {
    final cachedNotifications = _cachedNotifications;
    if (cachedNotifications == null) return false;

    for (final notification in cachedNotifications) {
      if (notification.id == id) {
        return !notification.isRead;
      }
    }

    return false;
  }

  void _replaceCachedNotification(NotificationModel notification) {
    final cachedNotifications = _cachedNotifications;
    if (cachedNotifications == null) {
      _cachedNotifications = [notification];
      return;
    }

    final updatedNotifications = <NotificationModel>[];
    var replaced = false;

    for (final cachedNotification in cachedNotifications) {
      if (cachedNotification.id == notification.id) {
        updatedNotifications.add(notification);
        replaced = true;
      } else {
        updatedNotifications.add(cachedNotification);
      }
    }

    if (!replaced) {
      updatedNotifications.insert(0, notification);
    }

    _cachedNotifications = updatedNotifications;
  }

  void dispose() {
    unawaited(_incomingController.close());
    unawaited(_unreadCountController.close());
  }

  /// Get cached notifications if available
  List<NotificationModel>? getCachedNotifications() => _cachedNotifications;

  /// Get the age of the last fetch
  Duration get lastFetchAge {
    if (_lastFetchTime == null) return const Duration(days: 1);
    return DateTime.now().difference(_lastFetchTime!);
  }
}
