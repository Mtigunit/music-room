import 'package:music_room/core/config/app_config.dart';
import 'package:music_room/features/search/data/models/search_filter_type.dart';

abstract class SearchResultModel {
  const SearchResultModel({required this.filterType});

  final SearchFilterType filterType;
}

class SearchTrackResultModel extends SearchResultModel {
  const SearchTrackResultModel({
    required this.providerTrackId,
    required this.title,
    required this.durationMs,
    this.artist,
    this.thumbnailUrl,
  }) : super(filterType: SearchFilterType.tracks);

  factory SearchTrackResultModel.fromJson(Map<String, dynamic> json) {
    return SearchTrackResultModel(
      providerTrackId: _string(json['providerTrackId']),
      title: _string(json['title'], fallback: 'Unknown track'),
      durationMs: _int(json['durationMs']),
      artist: _nullableString(json['artist']),
      thumbnailUrl: _nullableString(json['thumbnailUrl']),
    );
  }

  final String providerTrackId;
  final String title;
  final int durationMs;
  final String? artist;
  final String? thumbnailUrl;
}

class SearchEventResultModel extends SearchResultModel {
  const SearchEventResultModel({
    required this.id,
    required this.name,
    required this.status,
    required this.startDate,
    required this.hostName,
    required this.tags,
    this.description,
    this.coverImageUrl,
    this.locationLabel,
  }) : super(filterType: SearchFilterType.events);

  factory SearchEventResultModel.fromJson(Map<String, dynamic> json) {
    final hostJson = json['host'];
    final hostMap = hostJson is Map<String, dynamic>
        ? hostJson
        : <String, dynamic>{};

    return SearchEventResultModel(
      id: _string(json['id']),
      name: _string(json['name'], fallback: 'Untitled event'),
      status: _string(json['status'], fallback: 'UPCOMING'),
      startDate: _nullableString(json['startDate']),
      hostName: _string(hostMap['name'], fallback: 'Unknown host'),
      tags: _stringList(json['tags']),
      description: _nullableString(json['description']),
      coverImageUrl: _absoluteImageUrl(json['coverImage']),
      locationLabel: _buildLocationLabel(json),
    );
  }

  final String id;
  final String name;
  final String status;
  final String? startDate;
  final String hostName;
  final List<String> tags;
  final String? description;
  final String? coverImageUrl;
  final String? locationLabel;
}

class SearchPlaylistResultModel extends SearchResultModel {
  const SearchPlaylistResultModel({
    required this.id,
    required this.name,
    required this.visibility,
    required this.trackCount,
    required this.tags,
    required this.updatedAt,
    required this.ownerName,
    this.description,
    this.thumbnailUrl,
  }) : super(filterType: SearchFilterType.playlists);

  factory SearchPlaylistResultModel.fromJson(Map<String, dynamic> json) {
    final ownerJson = json['owner'];
    final ownerMap = ownerJson is Map<String, dynamic>
        ? ownerJson
        : <String, dynamic>{};
    final countJson = json['_count'];
    final countMap = countJson is Map<String, dynamic>
        ? countJson
        : <String, dynamic>{};

    return SearchPlaylistResultModel(
      id: _string(json['id']),
      name: _string(json['name'], fallback: 'Untitled playlist'),
      visibility: _string(json['visibility'], fallback: 'PUBLIC'),
      trackCount: _int(countMap['tracks']),
      tags: _stringList(json['tags']),
      updatedAt: _string(
        json['updatedAt'],
        fallback: DateTime.now().toIso8601String(),
      ),
      ownerName: _string(ownerMap['username'], fallback: 'Unknown owner'),
      description: _nullableString(json['description']),
      thumbnailUrl: _absoluteImageUrl(json['thumbnailUrl']),
    );
  }

  final String id;
  final String name;
  final String visibility;
  final int trackCount;
  final List<String> tags;
  final String updatedAt;
  final String ownerName;
  final String? description;
  final String? thumbnailUrl;
}

class SearchUserResultModel extends SearchResultModel {
  const SearchUserResultModel({
    required this.id,
    required this.username,
    required this.subscriptionTier,
    this.avatarUrl,
    this.shortBio,
  }) : super(filterType: SearchFilterType.users);

  factory SearchUserResultModel.fromJson(Map<String, dynamic> json) {
    return SearchUserResultModel(
      id: _string(json['id']),
      username: _string(json['username'], fallback: 'Unknown user'),
      avatarUrl: _absoluteImageUrl(json['avatarUrl']),
      shortBio: _extractShortBio(json['publicInfo']),
      subscriptionTier: _string(json['subscriptionTier'], fallback: 'BASIC'),
    );
  }

  final String id;
  final String username;
  final String subscriptionTier;
  final String? avatarUrl;
  final String? shortBio;
}

String _string(Object? value, {String fallback = ''}) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }

  return fallback;
}

String? _nullableString(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }

  if (value is DateTime) {
    return value.toIso8601String();
  }

  return value?.toString();
}

int _int(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return 0;
}

List<String> _stringList(Object? value) {
  if (value is! List<dynamic>) {
    return const <String>[];
  }

  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String? _absoluteImageUrl(Object? value) {
  final raw = _nullableString(value);
  if (raw == null) {
    return null;
  }

  if (raw.startsWith('http')) {
    return raw;
  }

  final baseUrl = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
  final relativePath = raw.replaceAll(RegExp('^/+'), '');
  return '$baseUrl/$relativePath';
}

String? _buildLocationLabel(Map<String, dynamic> json) {
  final lat = json['locationLat'];
  final lng = json['locationLng'];

  if (lat is num && lng is num) {
    return '${lat.toStringAsFixed(2)}, ${lng.toStringAsFixed(2)}';
  }

  return null;
}

String? _extractShortBio(Object? publicInfo) {
  if (publicInfo is Map<String, dynamic>) {
    return _nullableString(publicInfo['shortBio']);
  }

  if (publicInfo is String && publicInfo.trim().isNotEmpty) {
    return publicInfo.trim();
  }

  return null;
}
