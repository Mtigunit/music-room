/// Model representing the full event detail from GET /events/{eventId}.
class EventDetailModel {
  EventDetailModel({
    required this.id,
    required this.name,
    required this.status,
    required this.visibility,
    required this.invitingOnly,
    required this.hostId,
    this.description,
    this.coverImage,
    this.tags = const [],
    this.locationLat,
    this.locationLng,
    this.playbackStatus,
    this.currentTrackId,
  });

  factory EventDetailModel.fromJson(Map<String, dynamic> json) {
    return EventDetailModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled Event',
      description: json['description'] as String?,
      coverImage: json['coverImage'] as String?,
      status: json['status'] as String? ?? 'ACTIVE',
      visibility: json['visibility'] as String? ?? 'PUBLIC',
      invitingOnly: json['invitingOnly'] as bool? ?? false,
      tags: _parseTags(json['tags']),
      hostId: json['hostId'] as String? ?? '',
      locationLat: (json['locationLat'] as num?)?.toDouble(),
      locationLng: (json['locationLng'] as num?)?.toDouble(),
      playbackStatus: json['playbackStatus'] as String?,
      currentTrackId: json['currentTrackId'] as String?,
    );
  }

  final String id;
  final String name;
  final String? description;
  final String? coverImage;
  final String status;
  final String visibility;
  final bool invitingOnly;
  final List<String> tags;
  final String hostId;
  final double? locationLat;
  final double? locationLng;
  final String? playbackStatus;
  final String? currentTrackId;

  static List<String> _parseTags(Object? raw) {
    if (raw is List) {
      return raw.whereType<String>().toList(growable: false);
    }
    return const [];
  }
}
