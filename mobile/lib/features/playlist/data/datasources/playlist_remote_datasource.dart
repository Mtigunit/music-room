import 'package:dio/dio.dart';
import 'package:music_room/core/config/app_config.dart';
import 'package:music_room/core/network/api_client.dart';
import 'package:music_room/features/playlist/data/models/playlist_model.dart';
import 'package:music_room/features/playlist/domain/entities/playlist_entity.dart';

class ReorderSyncNotSupportedException implements Exception {
  const ReorderSyncNotSupportedException(this.message);

  final String message;

  @override
  String toString() => message;
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

  Future<List<TrackSearchEntity>> searchTracks(String query);

  Future<void> addTrackToPlaylist(String playlistId, TrackSearchEntity track);

  Future<void> addCollaboratorToPlaylist(
    String playlistId,
    String targetUserId,
  );

  Future<void> reorderPlaylistTracks(
    String playlistId,
    List<String> orderedPlaylistTrackIds,
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
  Future<void> addTrackToPlaylist(String playlistId, TrackSearchEntity track) {
    return _apiClient.post<dynamic>(
      '${AppConfig.playlistsEndpoint}/$playlistId/tracks',
      data: <String, dynamic>{
        'track': <String, dynamic>{
          'providerTrackId': track.providerTrackId,
          'title': track.title,
          'artist': track.artist ?? '',
          'durationMs': track.durationMs,
          if (track.thumbnailUrl != null) 'thumbnailUrl': track.thumbnailUrl,
        },
      },
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
  Future<void> reorderPlaylistTracks(
    String playlistId,
    List<String> orderedPlaylistTrackIds,
  ) async {
    // Backend currently does not expose a reorder endpoint.
    // Keep local ordering and fail gracefully at call site.
    throw const ReorderSyncNotSupportedException(
      'Backend API for reordering playlist tracks is not available yet.',
    );
  }
}
