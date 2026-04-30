import 'package:music_room/features/playlist/domain/entities/playlist_entity.dart';

class PlaylistModel {
  const PlaylistModel({
    required this.id,
    required this.name,
    required this.visibility,
    required this.trackCount,
    required this.tags,
    required this.updatedAt,
    this.ownerUserId,
    this.description,
    this.thumbnailUrl,
  });

  factory PlaylistModel.fromJson(Map<String, dynamic> json) {
    final countMap = json['_count'];
    final trackCountValue = countMap is Map<String, dynamic>
        ? countMap['tracks']
        : null;

    return PlaylistModel(
      id: _asString(json['id']),
      name: _asString(json['name']),
      visibility: _asString(json['visibility'], fallback: 'PUBLIC'),
      trackCount: _asInt(trackCountValue),
      tags: _asStringList(json['tags']),
      updatedAt: _asString(
        json['updatedAt'] ?? json['newUpdatedAt'],
        fallback: DateTime.now().toUtc().toIso8601String(),
      ),
      ownerUserId: _asNullableString(json['ownerId']),
      description: _asNullableString(json['description']),
      thumbnailUrl: _asNullableString(json['thumbnailUrl']),
    );
  }

  final String id;
  final String name;
  final String visibility;
  final int trackCount;
  final List<String> tags;
  final String updatedAt;
  final String? ownerUserId;
  final String? description;
  final String? thumbnailUrl;

  PlaylistEntity toEntity() {
    return PlaylistEntity(
      id: id,
      name: name,
      visibility: visibility,
      trackCount: trackCount,
      tags: tags,
      updatedAt: updatedAt,
      ownerUserId: ownerUserId,
      description: description,
      thumbnailUrl: thumbnailUrl,
    );
  }
}

class PlaylistTrackModel {
  const PlaylistTrackModel({
    required this.playlistTrackId,
    required this.providerTrackId,
    required this.title,
    required this.durationMs,
    required this.position,
    this.addedByUserId,
    this.artist,
    this.thumbnailUrl,
  });

  factory PlaylistTrackModel.fromJson(Map<String, dynamic> json) {
    final trackJson = json['track'];
    final trackMap = trackJson is Map<String, dynamic>
        ? trackJson
        : <String, dynamic>{};
    final addedByJson = json['addedBy'];
    final addedByMap = addedByJson is Map<String, dynamic>
        ? addedByJson
        : <String, dynamic>{};

    return PlaylistTrackModel(
      playlistTrackId: _asString(json['id']),
      providerTrackId: _asString(trackMap['providerTrackId']),
      title: _asString(trackMap['title'], fallback: 'Unknown track'),
      durationMs: _asInt(trackMap['durationMs']),
      position: _asInt(json['position']),
      addedByUserId: _asNullableString(
        json['addedById'] ?? addedByMap['id'],
      ),
      artist: _asNullableString(trackMap['artist']),
      thumbnailUrl: _asNullableString(trackMap['thumbnailUrl']),
    );
  }

  factory PlaylistTrackModel.fromEntity(PlaylistTrackEntity entity) {
    return PlaylistTrackModel(
      playlistTrackId: entity.playlistTrackId,
      providerTrackId: entity.providerTrackId,
      title: entity.title,
      durationMs: entity.durationMs,
      position: entity.position,
      addedByUserId: entity.addedByUserId,
      artist: entity.artist,
      thumbnailUrl: entity.thumbnailUrl,
    );
  }

  final String playlistTrackId;
  final String providerTrackId;
  final String title;
  final int durationMs;
  final int position;
  final String? addedByUserId;
  final String? artist;
  final String? thumbnailUrl;

  PlaylistTrackEntity toEntity() {
    return PlaylistTrackEntity(
      playlistTrackId: playlistTrackId,
      providerTrackId: providerTrackId,
      title: title,
      durationMs: durationMs,
      position: position,
      addedByUserId: addedByUserId,
      artist: artist,
      thumbnailUrl: thumbnailUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': playlistTrackId,
      'position': position,
      if (addedByUserId != null) 'addedById': addedByUserId,
      'track': <String, dynamic>{
        'providerTrackId': providerTrackId,
        'title': title,
        'durationMs': durationMs,
        if (artist != null) 'artist': artist,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      },
    };
  }
}

class PlaylistDetailsModel {
  const PlaylistDetailsModel({
    required this.id,
    required this.name,
    required this.ownerUserId,
    required this.visibility,
    required this.editLicense,
    required this.tracks,
    required this.tags,
    required this.updatedAt,
    required this.collaboratorIds,
    this.description,
  });

  factory PlaylistDetailsModel.fromJson(Map<String, dynamic> json) {
    final rawTracks = json['tracks'];
    final ownerJson = json['owner'];
    final ownerMap = ownerJson is Map<String, dynamic>
        ? ownerJson
        : <String, dynamic>{};
    final trackModels = rawTracks is List<dynamic>
        ? rawTracks
              .whereType<Map<String, dynamic>>()
              .map(PlaylistTrackModel.fromJson)
              .toList(growable: false)
        : const <PlaylistTrackModel>[];

    return PlaylistDetailsModel(
      id: _asString(json['id']),
      name: _asString(json['name']),
      ownerUserId: _asString(json['ownerId'] ?? ownerMap['id']),
      visibility: _asString(json['visibility'], fallback: 'PUBLIC'),
      editLicense: _asString(json['editLicense'], fallback: 'OPEN'),
      tags: _asStringList(json['tags']),
      updatedAt: _asString(
        json['updatedAt'] ?? json['newUpdatedAt'],
        fallback: DateTime.now().toUtc().toIso8601String(),
      ),
      collaboratorIds: _asCollaboratorIds(json['collaborators']),
      description: _asNullableString(json['description']),
      tracks: trackModels,
    );
  }

  factory PlaylistDetailsModel.fromEntity(PlaylistDetailsEntity entity) {
    return PlaylistDetailsModel(
      id: entity.id,
      name: entity.name,
      ownerUserId: entity.ownerUserId,
      visibility: entity.visibility,
      editLicense: entity.editLicense,
      tracks: entity.tracks
          .map(PlaylistTrackModel.fromEntity)
          .toList(growable: false),
      tags: entity.tags,
      updatedAt: entity.updatedAt,
      collaboratorIds: entity.collaboratorIds,
      description: entity.description,
    );
  }

  final String id;
  final String name;
  final String ownerUserId;
  final String visibility;
  final String editLicense;
  final String? description;
  final List<PlaylistTrackModel> tracks;
  final List<String> tags;
  final String updatedAt;
  final List<String> collaboratorIds;

  PlaylistDetailsEntity toEntity() {
    return PlaylistDetailsEntity(
      id: id,
      name: name,
      ownerUserId: ownerUserId,
      visibility: visibility,
      editLicense: editLicense,
      description: description,
      tags: tags,
      updatedAt: updatedAt,
      collaboratorIds: collaboratorIds,
      tracks: tracks
          .map((trackModel) => trackModel.toEntity())
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'ownerId': ownerUserId,
      'visibility': visibility,
      'editLicense': editLicense,
      'description': description,
      'updatedAt': updatedAt,
      'tags': tags,
      'tracks': tracks.map((track) => track.toJson()).toList(growable: false),
    };
  }
}

class TrackSearchModel {
  const TrackSearchModel({
    required this.providerTrackId,
    required this.title,
    required this.durationMs,
    this.artist,
    this.thumbnailUrl,
  });

  factory TrackSearchModel.fromJson(Map<String, dynamic> json) {
    return TrackSearchModel(
      providerTrackId: _asString(json['providerTrackId']),
      title: _asString(json['title'], fallback: 'Unknown track'),
      durationMs: _asInt(json['durationMs']),
      artist: _asNullableString(json['artist']),
      thumbnailUrl: _asNullableString(json['thumbnailUrl']),
    );
  }

  final String providerTrackId;
  final String title;
  final int durationMs;
  final String? artist;
  final String? thumbnailUrl;

  TrackSearchEntity toEntity() {
    return TrackSearchEntity(
      providerTrackId: providerTrackId,
      title: title,
      durationMs: durationMs,
      artist: artist,
      thumbnailUrl: thumbnailUrl,
    );
  }
}

String _asString(Object? value, {String fallback = ''}) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return fallback;
}

String? _asNullableString(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return 0;
}

List<String> _asStringList(Object? value) {
  if (value is! List<dynamic>) {
    return const <String>[];
  }

  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<String> _asCollaboratorIds(Object? value) {
  if (value is! List<dynamic>) {
    return const <String>[];
  }

  return value
      .map((item) {
        if (item is Map<String, dynamic>) {
          final rawUser = item['user'];
          if (rawUser is Map<String, dynamic>) {
            return _asNullableString(rawUser['id']);
          }

          return _asNullableString(item['userId']);
        }
        return null;
      })
      .whereType<String>()
      .toList(growable: false);
}
