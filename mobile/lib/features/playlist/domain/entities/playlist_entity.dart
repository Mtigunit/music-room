class PlaylistEntity {
  const PlaylistEntity({
    required this.id,
    required this.name,
    required this.visibility,
    required this.trackCount,
    required this.tags,
    this.description,
    this.thumbnailUrl,
  });

  final String id;
  final String name;
  final String visibility;
  final int trackCount;
  final List<String> tags;
  final String? description;
  final String? thumbnailUrl;
}

class PlaylistTrackEntity {
  const PlaylistTrackEntity({
    required this.playlistTrackId,
    required this.providerTrackId,
    required this.title,
    required this.durationMs,
    required this.position,
    this.artist,
    this.thumbnailUrl,
  });

  final String playlistTrackId;
  final String providerTrackId;
  final String title;
  final int durationMs;
  final int position;
  final String? artist;
  final String? thumbnailUrl;
}

class PlaylistDetailsEntity {
  const PlaylistDetailsEntity({
    required this.id,
    required this.name,
    required this.visibility,
    required this.editLicense,
    required this.tracks,
    required this.tags,
    this.description,
  });

  final String id;
  final String name;
  final String visibility;
  final String editLicense;
  final String? description;
  final List<PlaylistTrackEntity> tracks;
  final List<String> tags;
}

class TrackSearchEntity {
  const TrackSearchEntity({
    required this.providerTrackId,
    required this.title,
    required this.durationMs,
    this.artist,
    this.thumbnailUrl,
  });

  final String providerTrackId;
  final String title;
  final int durationMs;
  final String? artist;
  final String? thumbnailUrl;
}
