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
  });

  factory EventTrackModel.fromJson(Map<String, dynamic> json) {
    return EventTrackModel(
      id: json['id'] as String? ?? '',
      trackId: json['trackId'] as String? ?? '',
      addedById: json['addedById'] as String? ?? '',
      voteScore: json['voteScore'] as int? ?? 0,
      status: json['status'] as String? ?? 'QUEUED',
      providerTrackId: json['providerTrackId'] as String? ?? '',
      title: json['title'] as String? ?? 'Unknown Title',
      artist: json['artist'] as String? ?? 'Unknown Artist',
      durationMs: json['durationMs'] as int? ?? 0,
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
    );
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

  /// Formats durationMs into a human-readable "M:SS" string.
  String get formattedDuration {
    final totalSeconds = durationMs ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
