class PlaylistEntity {
  const PlaylistEntity({
    required this.id,
    required this.name,
    required this.visibility,
    required this.trackCount,
    required this.tags,
    required this.updatedAt,
    this.ownerUserId,
    this.description,
    this.thumbnailUrl,
    this.collageImageUrls = const <String>[],
  });

  final String id;
  final String name;
  final String visibility;
  final int trackCount;
  final List<String> tags;
  final String updatedAt;
  final String? ownerUserId;
  final String? description;
  final String? thumbnailUrl;
  final List<String> collageImageUrls;
}

class PlaylistTrackEntity {
  const PlaylistTrackEntity({
    required this.playlistTrackId,
    required this.providerTrackId,
    required this.title,
    required this.durationMs,
    required this.position,
    this.addedByUserId,
    this.artist,
    this.thumbnailUrl,
  });

  final String playlistTrackId;
  final String providerTrackId;
  final String title;
  final int durationMs;
  final int position;
  final String? addedByUserId;
  final String? artist;
  final String? thumbnailUrl;
}

class PlaylistDetailsEntity {
  const PlaylistDetailsEntity({
    required this.id,
    required this.name,
    required this.ownerUserId,
    required this.visibility,
    required this.editLicense,
    required this.tracks,
    required this.tags,
    required this.updatedAt,
    this.collaboratorIds = const <String>[],
    this.description,
  });

  static const int maxCollaborators = 50;

  int get collaboratorCount => collaboratorIds.length;

  final String id;
  final String name;
  final String ownerUserId;
  final String visibility;
  final String editLicense;
  final String? description;
  final List<PlaylistTrackEntity> tracks;
  final List<String> tags;
  final String updatedAt;
  final List<String> collaboratorIds;
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
