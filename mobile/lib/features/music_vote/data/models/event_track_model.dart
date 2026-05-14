/// Model representing a track in the event queue from
/// GET /events/{eventId}/tracks and POST /events/{eventId}/tracks.
class EventTrackModel {
  EventTrackModel({
    required this.id,
    required this.trackId,
    required this.addedById,
    required this.voteScore,
    required this.status,
    required this.providerTrackId,
    required this.title,
    required this.artist,
    required this.durationMs,
    required this.thumbnailUrl,
    this.isVoted = false,
    this.currentTrackStartedAt,
    this.pausedPlaybackPositionMs,
  });

  factory EventTrackModel.fromJson(Map<String, dynamic> json) {
    final trackData = json['track'] as Map<String, dynamic>?;

    return EventTrackModel(
      id: json['id'] as String? ?? '',
      trackId:
          json['trackId'] as String? ?? (trackData?['id'] as String? ?? ''),
      addedById: json['addedById'] as String? ?? '',
      voteScore: json['voteScore'] as int? ?? 0,
      status: json['status'] as String? ?? 'QUEUED',
      providerTrackId:
          json['providerTrackId'] as String? ??
          (trackData?['providerTrackId'] as String? ?? ''),
      title:
          json['title'] as String? ??
          (trackData?['title'] as String? ?? 'Unknown Title'),
      artist:
          json['artist'] as String? ??
          (trackData?['artist'] as String? ?? 'Unknown Artist'),
      durationMs:
          json['durationMs'] as int? ?? (trackData?['durationMs'] as int? ?? 0),
      thumbnailUrl:
          json['thumbnailUrl'] as String? ??
          (trackData?['thumbnailUrl'] as String? ?? ''),
      isVoted: json['isVoted'] as bool? ?? false,
      currentTrackStartedAt: _parseDate(json['currentTrackStartedAt']),
      pausedPlaybackPositionMs: json['pausedPlaybackPositionMs'] is num
          ? (json['pausedPlaybackPositionMs'] as num).toInt()
          : null,
    );
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  final String id;
  final String trackId;
  final String addedById;
  final int voteScore;
  final String status;
  final String providerTrackId;
  final String title;
  final String artist;
  final int durationMs;
  final String thumbnailUrl;
  final bool isVoted;
  final DateTime? currentTrackStartedAt;
  final int? pausedPlaybackPositionMs;

  EventTrackModel copyWith({
    String? id,
    String? trackId,
    String? addedById,
    int? voteScore,
    String? status,
    String? providerTrackId,
    String? title,
    String? artist,
    int? durationMs,
    String? thumbnailUrl,
    bool? isVoted,
    DateTime? currentTrackStartedAt,
    int? pausedPlaybackPositionMs,
    bool clearCurrentTrackStartedAt = false,
    bool clearPausedPlaybackPositionMs = false,
  }) {
    return EventTrackModel(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      addedById: addedById ?? this.addedById,
      voteScore: voteScore ?? this.voteScore,
      status: status ?? this.status,
      providerTrackId: providerTrackId ?? this.providerTrackId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      durationMs: durationMs ?? this.durationMs,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isVoted: isVoted ?? this.isVoted,
      currentTrackStartedAt: clearCurrentTrackStartedAt
          ? null
          : (currentTrackStartedAt ?? this.currentTrackStartedAt),
      pausedPlaybackPositionMs: clearPausedPlaybackPositionMs
          ? null
          : (pausedPlaybackPositionMs ?? this.pausedPlaybackPositionMs),
    );
  }

  /// Formats durationMs into a human-readable "M:SS" string.
  String get formattedDuration {
    final totalSeconds = durationMs ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
