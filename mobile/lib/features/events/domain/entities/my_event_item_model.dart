import 'package:music_room/core/config/app_config.dart';

/// Maps the subset of fields returned by `GET /events/invited` and
/// `GET /events/hosting` that are required to render a `MyEventListTile`.
///
/// Fields ignored intentionally: tracks, policies, collaborators, etc.
class MyEventItemModel {
  const MyEventItemModel({
    required this.id,
    required this.name,
    required this.status,
    required this.startDate,
    required this.hostName,
    required this.hostId,
    required this.membersCount,
    this.coverImage,
    this.firstTrack,
  });

  factory MyEventItemModel.fromJson(Map<String, dynamic> json) {
    final hostMap = json['host'];
    final hostName =
        (hostMap is Map<String, dynamic> && hostMap['name'] is String)
        ? hostMap['name'] as String
        : '';

    var parsedStartDate = DateTime.now();
    final rawDate = json['startDate'];
    if (rawDate is String && rawDate.isNotEmpty) {
      parsedStartDate = DateTime.tryParse(rawDate) ?? parsedStartDate;
    }

    return MyEventItemModel(
      id: json['id'] as String,
      name: json['name'] as String,
      status: json['status'] as String,
      startDate: parsedStartDate,
      hostName: hostName,
      hostId: (hostMap is Map<String, dynamic> && hostMap['id'] is String)
          ? hostMap['id'] as String
          : (json['hostId'] as String? ?? ''),
      membersCount: _parseMembersCount(json['membersCount']),
      coverImage: _buildCoverImageUrl(json['coverImage'] as String?),
      firstTrack: _buildCoverImageUrl(json['firstTrack'] as String?),
    );
  }

  final String id;
  final String name;

  /// One of: 'LIVE', 'UPCOMING', 'ENDED'.
  final String status;

  final DateTime startDate;

  /// Display name of the event host (from `host.name` in the JSON payload).
  final String hostName;

  /// Unique identifier of the event host.
  final String hostId;

  /// Number of attendees/invites returned by the backend.
  final int membersCount;

  /// URL string for the cover image, if provided by the backend.
  final String? coverImage;

  /// URL string for the first track thumbnail, if provided by the backend.
  final String? firstTrack;

  /// Builds a fully-qualified image URL from the [relativePath] returned by
  /// the backend (e.g. `uploads/cover.jpg` → `http://host:3000/uploads/cover.jpg`).
  ///
  /// Returns `null` when [relativePath] is null/empty, and returns the path
  /// unchanged when it already starts with `http`.
  static String? _buildCoverImageUrl(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return null;
    if (relativePath.startsWith('http')) return relativePath;

    // Strip trailing slash from base URL to avoid double slashes.
    final base = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    // Strip leading slash from the relative path to be safe.
    final path = relativePath.replaceAll(RegExp('^/+'), '');
    return '$base/$path';
  }

  static int _parseMembersCount(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }
}
