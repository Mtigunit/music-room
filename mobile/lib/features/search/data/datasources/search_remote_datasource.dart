import 'package:dio/dio.dart';
import 'package:music_room/core/config/app_config.dart';
import 'package:music_room/core/network/api_client.dart';
import 'package:music_room/features/search/data/models/search_result_models.dart';

abstract class ISearchRemoteDataSource {
  Future<List<SearchEventResultModel>> searchEvents(String query);
  Future<List<SearchTrackResultModel>> searchTracks(String query);
  Future<List<SearchPlaylistResultModel>> searchPlaylists(String query);
  Future<List<SearchUserResultModel>> searchUsers(String query);
}

class SearchRemoteDataSource implements ISearchRemoteDataSource {
  SearchRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<SearchTrackResultModel>> searchTracks(String query) async {
    final response = await _apiClient.get<dynamic>(
      AppConfig.trackSearchEndpoint,
      queryParameters: <String, dynamic>{'q': query.trim()},
    );

    return _parseListResponse(response, SearchTrackResultModel.fromJson);
  }

  @override
  Future<List<SearchEventResultModel>> searchEvents(String query) async {
    final response = await _apiClient.get<dynamic>(
      AppConfig.eventsEndpoint,
      queryParameters: <String, dynamic>{
        'search': query.trim(),
        'page': 1,
        'limit': 20,
      },
    );

    return _parseListResponse(response, SearchEventResultModel.fromJson);
  }

  @override
  Future<List<SearchPlaylistResultModel>> searchPlaylists(String query) async {
    final response = await _apiClient.get<dynamic>(
      AppConfig.explorePlaylistsEndpoint,
      queryParameters: <String, dynamic>{
        'q': query.trim(),
        'page': 1,
        'limit': 20,
      },
    );

    return _parseListResponse(response, SearchPlaylistResultModel.fromJson);
  }

  @override
  Future<List<SearchUserResultModel>> searchUsers(String query) async {
    final response = await _apiClient.get<dynamic>(
      AppConfig.searchUsersEndpoint,
      queryParameters: <String, dynamic>{
        'q': query.trim(),
        'page': 1,
        'limit': 20,
      },
    );

    return _parseListResponse(response, SearchUserResultModel.fromJson);
  }

  List<T> _parseListResponse<T, R>(
    Response<R> response,
    T Function(Map<String, dynamic>) mapper,
  ) {
    try {
      final body = response.data;
      if (body == null) return <T>[];

      final List<dynamic> items;
      if (body is List<dynamic>) {
        items = body;
      } else if (body is Map<String, dynamic>) {
        final data = body['data'];
        if (data is List<dynamic>) {
          items = data;
        } else {
          items = const <dynamic>[];
        }
      } else {
        items = const <dynamic>[];
      }

      return items
          .whereType<Map<String, dynamic>>()
          .map(mapper)
          .toList(growable: false);
    } on Object catch (_) {
      // Be defensive: never throw from parsing — return empty list so callers
      // can treat the result as 'no items' and stop loading.
      return <T>[];
    }
  }
}
