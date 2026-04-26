import 'package:dio/dio.dart';
import 'package:music_room/core/config/app_config.dart';
import 'package:music_room/core/network/api_client.dart';
import 'package:music_room/features/playlist/data/models/playlist_model.dart';
import 'package:music_room/features/playlist/domain/entities/playlist_entity.dart';

class PlaylistConflictException implements Exception {
  const PlaylistConflictException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PlaylistMutationResult {
  const PlaylistMutationResult({required this.newUpdatedAt});

  final String newUpdatedAt;
}

class PlaylistAddTrackResult {
  const PlaylistAddTrackResult({
    required this.newUpdatedAt,
    required this.playlistTrack,
  });

  final String newUpdatedAt;
  final PlaylistTrackEntity playlistTrack;
}

class PlaylistRemoveTrackResult {
  const PlaylistRemoveTrackResult({
    required this.newUpdatedAt,
    required this.deletedTrack,
  });

  final String newUpdatedAt;
  final PlaylistTrackEntity deletedTrack;
}

class CreatePlaylistRequest {
  const CreatePlaylistRequest({
    required this.name,
    required this.visibility,
    required this.editLicense,
    this.description,
    this.tags,
  });

  final String name;
  final String visibility;
  final String editLicense;
  final String? description;
  final List<String>? tags;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'visibility': visibility,
      'editLicense': editLicense,
      if (description != null && description!.trim().isNotEmpty)
        'description': description!.trim(),
      if (tags != null && tags!.isNotEmpty) 'tags': tags,
    };
  }
}

class UpdatePlaylistRequest {
  const UpdatePlaylistRequest({
    this.name,
    this.visibility,
    this.editLicense,
    this.description,
    this.tags,
  });

  final String? name;
  final String? visibility;
  final String? editLicense;
  final String? description;
  final List<String>? tags;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (name != null) 'name': name,
      if (visibility != null) 'visibility': visibility,
      if (editLicense != null) 'editLicense': editLicense,
      if (description != null) 'description': description,
      if (tags != null) 'tags': tags,
    };
  }
}

abstract class IPlaylistRemoteDataSource {
  Future<List<PlaylistEntity>> fetchMyPlaylists({
    int page = 1,
    int limit = 50,
  });

  Future<void> createPlaylist(CreatePlaylistRequest request);

  Future<PlaylistDetailsEntity> fetchPlaylistDetails(String playlistId);

  Future<void> updatePlaylist(
    String playlistId,
    UpdatePlaylistRequest request,
  );

  Future<void> deletePlaylist(String playlistId);

  Future<List<TrackSearchEntity>> searchTracks(String query);

  Future<PlaylistAddTrackResult> addTrackToPlaylist(
    String playlistId,
    TrackSearchEntity track,
  );

  Future<PlaylistRemoveTrackResult> removeTrackFromPlaylist(
    String playlistId,
    String playlistTrackId,
  );

  Future<void> addCollaboratorToPlaylist(
    String playlistId,
    String targetUserId,
  );

  Future<PlaylistMutationResult> reorderPlaylistTracks(
    String playlistId,
    String playlistTrackId,
    int newPosition,
    String baseUpdatedAt,
  );
}

class PlaylistRemoteDataSource implements IPlaylistRemoteDataSource {
  PlaylistRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<PlaylistEntity>> fetchMyPlaylists({
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      AppConfig.playlistsEndpoint,
      queryParameters: <String, dynamic>{
        'page': page,
        'limit': limit,
      },
    );

    final body = response.data;
    if (body == null) {
      return const <PlaylistEntity>[];
    }

    final data = body['data'];
    if (data is! List<dynamic>) {
      return const <PlaylistEntity>[];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map((item) => PlaylistModel.fromJson(item).toEntity())
        .toList(growable: false);
  }

  @override
  Future<void> createPlaylist(CreatePlaylistRequest request) async {
    await _apiClient.post<dynamic>(
      AppConfig.playlistsEndpoint,
      data: request.toJson(),
    );
  }

  @override
  Future<PlaylistDetailsEntity> fetchPlaylistDetails(String playlistId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '${AppConfig.playlistsEndpoint}/$playlistId',
    );
    final body = response.data;
    if (body == null) {
      throw DioException.badResponse(
        statusCode: 500,
        requestOptions: RequestOptions(path: AppConfig.playlistsEndpoint),
        response: Response<Map<String, dynamic>>(
          data: <String, dynamic>{},
          requestOptions: RequestOptions(path: AppConfig.playlistsEndpoint),
          statusCode: 500,
        ),
      );
    }

    return PlaylistDetailsModel.fromJson(body).toEntity();
  }

  @override
  Future<void> updatePlaylist(
    String playlistId,
    UpdatePlaylistRequest request,
  ) {
    return _apiClient.patch<dynamic>(
      '${AppConfig.playlistsEndpoint}/$playlistId',
      data: request.toJson(),
    );
  }

  @override
  Future<void> deletePlaylist(String playlistId) {
    return _apiClient.delete<dynamic>(
      '${AppConfig.playlistsEndpoint}/$playlistId',
    );
  }

  @override
  Future<List<TrackSearchEntity>> searchTracks(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const <TrackSearchEntity>[];
    }

    final response = await _apiClient.get<List<dynamic>>(
      AppConfig.trackSearchEndpoint,
      queryParameters: <String, dynamic>{'q': trimmed},
    );
    final body = response.data;
    if (body == null) {
      return const <TrackSearchEntity>[];
    }

    return body
        .whereType<Map<String, dynamic>>()
        .map((json) => TrackSearchModel.fromJson(json).toEntity())
        .toList(growable: false);
  }

  @override
  Future<PlaylistAddTrackResult> addTrackToPlaylist(
    String playlistId,
    TrackSearchEntity track,
  ) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '${AppConfig.playlistsEndpoint}/$playlistId/tracks',
      data: <String, dynamic>{
        'providerTrackId': track.providerTrackId,
      },
    );

    final body = response.data;
    final payload = body is Map<String, dynamic> ? body : <String, dynamic>{};
    final rawTrack = payload['track'];
    final trackJson = rawTrack is Map<String, dynamic>
        ? rawTrack
        : <String, dynamic>{};

    return PlaylistAddTrackResult(
      newUpdatedAt: _extractUpdatedAt(payload),
      playlistTrack: PlaylistTrackModel.fromJson(trackJson).toEntity(),
    );
  }

  @override
  Future<PlaylistRemoveTrackResult> removeTrackFromPlaylist(
    String playlistId,
    String playlistTrackId,
  ) async {
    final response = await _apiClient.delete<Map<String, dynamic>>(
      '${AppConfig.playlistsEndpoint}/$playlistId/tracks/$playlistTrackId',
    );

    final body = response.data;
    final payload = body is Map<String, dynamic> ? body : <String, dynamic>{};
    final deletedTrackJson = payload['deletedTrack'];
    final deletedTrackMap = deletedTrackJson is Map<String, dynamic>
        ? deletedTrackJson
        : <String, dynamic>{};

    return PlaylistRemoveTrackResult(
      newUpdatedAt: _extractUpdatedAt(payload),
      deletedTrack: PlaylistTrackModel.fromJson(deletedTrackMap).toEntity(),
    );
  }

  @override
  Future<void> addCollaboratorToPlaylist(
    String playlistId,
    String targetUserId,
  ) {
    return _apiClient.post<dynamic>(
      '${AppConfig.playlistsEndpoint}/$playlistId/collaborators',
      data: <String, dynamic>{'targetUserId': targetUserId.trim()},
    );
  }

  @override
  Future<PlaylistMutationResult> reorderPlaylistTracks(
    String playlistId,
    String playlistTrackId,
    int newPosition,
    String baseUpdatedAt,
  ) async {
    try {
      final response = await _apiClient.patch<Map<String, dynamic>>(
        '${AppConfig.playlistsEndpoint}/$playlistId/tracks/$playlistTrackId/reorder',
        data: <String, dynamic>{
          'newPosition': newPosition,
          'baseUpdatedAt': baseUpdatedAt,
        },
      );

      final body = response.data;
      final rawValue = body?['newUpdatedAt'] ?? body?['updatedAt'];
      final newUpdatedAt = rawValue is String
          ? rawValue
          : DateTime.now().toUtc().toIso8601String();

      return PlaylistMutationResult(newUpdatedAt: newUpdatedAt);
    } on DioException catch (error) {
      if (error.response?.statusCode == 409) {
        throw const PlaylistConflictException('Playlist update conflict');
      }
      rethrow;
    }
  }

  String _extractUpdatedAt(Map<String, dynamic> payload) {
    final rawValue = payload['newUpdatedAt'] ?? payload['updatedAt'];
    if (rawValue is String && rawValue.isNotEmpty) {
      return rawValue;
    }
    return DateTime.now().toUtc().toIso8601String();
  }
}
