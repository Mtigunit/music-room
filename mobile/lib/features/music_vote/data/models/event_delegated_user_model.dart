import 'package:music_room/core/config/app_config.dart';

/// User entry representing active control delegations returned by
/// `GET /events/{eventId}/delegations`.
/// Can parse both nested relationships
/// (`delegatee: { id, username, avatarUrl }`)
/// and flat shapes.
class EventDelegatedUserModel {
  const EventDelegatedUserModel({
    required this.id,
    required this.username,
    this.avatarUrl,
  });

  factory EventDelegatedUserModel.fromJson(Map<String, dynamic> json) {
    // Handle Prisma include structure:
    // { "id": "delegationId", "delegatee": { "id": "userId", ... } }
    final delegatee = json['delegatee'];
    if (delegatee is Map<String, dynamic>) {
      return EventDelegatedUserModel(
        id: (delegatee['id'] as String? ?? '').trim(),
        username: (delegatee['username'] as String? ?? 'Unknown').trim(),
        avatarUrl: _absoluteImageUrl(
          delegatee['avatarUrl'] ?? delegatee['avatar'],
        ),
      );
    }

    // Flat structure:
    // { "id": "userId", "username": "username", "avatar": "avatar" }
    return EventDelegatedUserModel(
      id: (json['id'] as String? ?? '').trim(),
      username: (json['username'] as String? ?? 'Unknown').trim(),
      avatarUrl: _absoluteImageUrl(
        json['avatar'] ?? json['avatarUrl'],
      ),
    );
  }

  final String id;
  final String username;
  final String? avatarUrl;

  /// Resolves relative avatar URLs into absolute ones using the API base.
  static String? _absoluteImageUrl(Object? raw) {
    if (raw is! String) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    final base = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final path = value.replaceAll(RegExp('^/+'), '');
    return '$base/$path';
  }
}
