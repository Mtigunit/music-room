import 'dart:convert';
import 'package:music_room/features/playlist/data/models/playlist_model.dart';
import 'package:music_room/features/playlist/domain/entities/playlist_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CachedPlaylistSnapshot {
  const CachedPlaylistSnapshot({
    required this.playlist,
    required this.updatedAt,
    required this.lastSyncedAt,
  });

  final PlaylistDetailsEntity playlist;
  final String updatedAt;
  final String lastSyncedAt;
}

abstract class IPlaylistCacheDataSource {
  Future<CachedPlaylistSnapshot?> getPlaylist(String playlistId);

  Future<void> savePlaylist({
    required String playlistId,
    required PlaylistDetailsEntity playlist,
    required String updatedAt,
    required String lastSyncedAt,
  });
}

class PlaylistCacheDataSource implements IPlaylistCacheDataSource {
  PlaylistCacheDataSource({required SharedPreferences preferences})
    : _preferences = preferences;

  final SharedPreferences _preferences;

  static const String _cachePrefix = 'playlist_cache_v1_';

  String _key(String playlistId) => '$_cachePrefix$playlistId';

  @override
  Future<CachedPlaylistSnapshot?> getPlaylist(String playlistId) async {
    final payload = _preferences.getString(_key(playlistId));
    if (payload == null || payload.isEmpty) {
      return null;
    }

    try {
      final json = jsonDecode(payload);
      if (json is! Map<String, dynamic>) {
        return null;
      }

      final playlistJson = json['playlist'];
      if (playlistJson is! Map<String, dynamic>) {
        return null;
      }

      final playlist = PlaylistDetailsModel.fromJson(playlistJson).toEntity();
      final updatedAt = (json['updatedAt'] as String?) ?? '';
      final lastSyncedAt = (json['lastSyncedAt'] as String?) ?? '';

      if (updatedAt.isEmpty || lastSyncedAt.isEmpty) {
        return null;
      }

      return CachedPlaylistSnapshot(
        playlist: playlist,
        updatedAt: updatedAt,
        lastSyncedAt: lastSyncedAt,
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> savePlaylist({
    required String playlistId,
    required PlaylistDetailsEntity playlist,
    required String updatedAt,
    required String lastSyncedAt,
  }) async {
    final payload = jsonEncode(<String, dynamic>{
      'playlist': PlaylistDetailsModel.fromEntity(playlist).toJson(),
      'updatedAt': updatedAt,
      'lastSyncedAt': lastSyncedAt,
    });

    await _preferences.setString(_key(playlistId), payload);
  }
}
