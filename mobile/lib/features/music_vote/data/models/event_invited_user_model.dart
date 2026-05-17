import 'package:music_room/core/config/app_config.dart';

/// User entry returned by `GET /events/{eventId}/invited`.
class EventInvitedUserModel {
  const EventInvitedUserModel({
    required this.id,
    required this.username,
    this.avatarUrl,
  });

  factory EventInvitedUserModel.fromJson(Map<String, dynamic> json) {
    return EventInvitedUserModel(
      id: (json['id'] as String? ?? '').trim(),
      username: (json['username'] as String? ?? 'Unknown').trim(),
      avatarUrl: _absoluteImageUrl(json['avatarUrl']),
    );
  }

  final String id;
  final String username;
  final String? avatarUrl;

  /// Resolves a (possibly relative) avatar URL into an absolute one against
  /// [AppConfig.apiBaseUrl] so the image widget can fetch it directly.
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
