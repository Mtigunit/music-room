class TrackModel {
  TrackModel({
    required this.providerTrackId,
    required this.title,
    required this.artist,
    required this.durationMs,
    required this.thumbnailUrl,
  });

  factory TrackModel.fromJson(Map<String, dynamic> json) {
    return TrackModel(
      providerTrackId: json['providerTrackId'] as String? ?? '',
      title: json['title'] as String? ?? 'Unknown Title',
      artist: json['artist'] as String? ?? 'Unknown Artist',
      durationMs: json['durationMs'] as int? ?? 0,
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
    );
  }
  final String providerTrackId;
  final String title;
  final String artist;
  final int durationMs;
  final String thumbnailUrl;

  Map<String, dynamic> toJson() {
    return {
      'providerTrackId': providerTrackId,
      'title': title,
      'artist': artist,
      'durationMs': durationMs,
      'thumbnailUrl': thumbnailUrl,
    };
  }
}
