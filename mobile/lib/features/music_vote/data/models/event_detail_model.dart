/// Policies governing voting restrictions for an event.
class EventPolicies {
  const EventPolicies({
    this.locationAndTime = false,
    this.invitingOnly = false,
    this.startDate,
    this.endDate,
  });

  factory EventPolicies.fromJson(Map<String, dynamic> json) {
    return EventPolicies(
      locationAndTime: json['locationAndTime'] as bool? ?? false,
      invitingOnly: json['invitingOnly'] as bool? ?? false,
      startDate: _parseDate(json['startDate']),
      endDate: _parseDate(json['endDate']),
    );
  }

  final bool locationAndTime;
  final bool invitingOnly;
  final DateTime? startDate;
  final DateTime? endDate;

  EventPolicies copyWith({
    bool? locationAndTime,
    bool? invitingOnly,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return EventPolicies(
      locationAndTime: locationAndTime ?? this.locationAndTime,
      invitingOnly: invitingOnly ?? this.invitingOnly,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }

  /// Whether the current time falls within the [startDate]–[endDate] window.
  ///
  /// Returns `true` (voting open) when no time window is defined.
  bool get isVotingOpen {
    if (startDate == null && endDate == null) return true;
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw);
    }
    return null;
  }
}

/// Model representing the full event detail from GET /events/{eventId}.
class EventDetailModel {
  EventDetailModel({
    required this.id,
    required this.name,
    required this.status,
    required this.visibility,
    required this.hostId,
    this.description,
    this.coverImage,
    this.tags = const [],
    this.policies = const EventPolicies(),
    this.locationLat,
    this.locationLng,
    this.playbackStatus,
    this.currentTrackId,
    this.startDate,
    this.isInvited = false,
    this.isHost = false,
  });

  factory EventDetailModel.fromJson(Map<String, dynamic> json) {
    // Parse the nested policies object from the backend response.
    // Falls back to root-level `invitingOnly` for backward compatibility.
    final policiesJson = json['policies'];
    final EventPolicies policies;
    if (policiesJson is Map<String, dynamic>) {
      policies = EventPolicies.fromJson(policiesJson);
    } else {
      policies = EventPolicies(
        invitingOnly: json['invitingOnly'] as bool? ?? false,
      );
    }

    return EventDetailModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled Event',
      description: json['description'] as String?,
      coverImage: json['coverImage'] as String?,
      status: json['status'] as String? ?? 'ACTIVE',
      visibility: json['visibility'] as String? ?? 'PUBLIC',
      policies: policies,
      tags: _parseTags(json['tags']),
      hostId: json['hostId'] as String? ?? '',
      locationLat: (json['locationLat'] as num?)?.toDouble(),
      locationLng: (json['locationLng'] as num?)?.toDouble(),
      playbackStatus: json['playbackStatus'] as String?,
      currentTrackId: json['currentTrackId'] as String?,
      startDate: _parseDate(json['startDate']),
      isInvited: json['isInvited'] as bool? ?? false,
      isHost: json['isHost'] as bool? ?? false,
    );
  }

  final String id;
  final String name;
  final String? description;
  final String? coverImage;
  final String status;
  final String visibility;
  final EventPolicies policies;
  final List<String> tags;
  final String hostId;
  final double? locationLat;
  final double? locationLng;
  final String? playbackStatus;
  final String? currentTrackId;
  final DateTime? startDate;
  final bool isInvited;
  final bool isHost;

  EventDetailModel copyWith({
    String? id,
    String? name,
    String? description,
    String? coverImage,
    String? status,
    String? visibility,
    EventPolicies? policies,
    List<String>? tags,
    String? hostId,
    double? locationLat,
    double? locationLng,
    String? playbackStatus,
    String? currentTrackId,
    DateTime? startDate,
    bool? isInvited,
    bool? isHost,
  }) {
    return EventDetailModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverImage: coverImage ?? this.coverImage,
      status: status ?? this.status,
      visibility: visibility ?? this.visibility,
      policies: policies ?? this.policies,
      tags: tags ?? this.tags,
      hostId: hostId ?? this.hostId,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      playbackStatus: playbackStatus ?? this.playbackStatus,
      currentTrackId: currentTrackId ?? this.currentTrackId,
      startDate: startDate ?? this.startDate,
      isInvited: isInvited ?? this.isInvited,
      isHost: isHost ?? this.isHost,
    );
  }

  static List<String> _parseTags(Object? raw) {
    if (raw is List) {
      return raw.whereType<String>().toList(growable: false);
    }
    return const [];
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw);
    }
    return null;
  }
}
