import 'package:dio/dio.dart';
import 'package:music_room/core/config/app_config.dart';
import 'package:music_room/core/network/api_client.dart';
import 'package:music_room/features/events/domain/entities/my_event_item_model.dart';

abstract class IHomeRemoteDataSource {
  Future<List<MyEventItemModel>> fetchExploreEvents({
    int page = 1,
    int limit = 20,
    String? tags,
    String? status,
    String? search,
  });

  Future<List<MyEventItemModel>> fetchFriendsEvents({
    int page = 1,
    int limit = 20,
    String? tags,
    String? status,
    String? search,
  });
}

class HomeRemoteDataSource implements IHomeRemoteDataSource {
  HomeRemoteDataSource({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<MyEventItemModel>> fetchExploreEvents({
    int page = 1,
    int limit = 20,
    String? tags,
    String? status,
    String? search,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'page': page,
        'limit': limit,
      };

      final normalizedTags = tags?.trim().toLowerCase();
      if (normalizedTags != null &&
          normalizedTags.isNotEmpty &&
          normalizedTags != 'all') {
        queryParameters['tags'] = tags!.trim().toUpperCase();
      }

      final normalizedStatus = status?.trim().toLowerCase();
      if (normalizedStatus != null &&
          normalizedStatus.isNotEmpty &&
          normalizedStatus != 'all') {
        queryParameters['status'] = status!.trim().toUpperCase();
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParameters['search'] = search.trim();
      }

      final response = await _apiClient.get<dynamic>(
        AppConfig.eventsExploreEndpoint,
        queryParameters: queryParameters,
      );

      return _parseEventListResponse(response);
    } on DioException {
      rethrow;
    } on Object catch (e) {
      throw DioException(
        requestOptions: RequestOptions(path: AppConfig.eventsExploreEndpoint),
        error: e,
      );
    }
  }

  @override
  Future<List<MyEventItemModel>> fetchFriendsEvents({
    int page = 1,
    int limit = 20,
    String? tags,
    String? status,
    String? search,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'page': page,
        'limit': limit,
      };

      final normalizedTags = tags?.trim().toLowerCase();
      if (normalizedTags != null &&
          normalizedTags.isNotEmpty &&
          normalizedTags != 'all') {
        queryParameters['tags'] = tags!.trim().toUpperCase();
      }

      final normalizedStatus = status?.trim().toLowerCase();
      if (normalizedStatus != null &&
          normalizedStatus.isNotEmpty &&
          normalizedStatus != 'all') {
        queryParameters['status'] = status!.trim().toUpperCase();
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParameters['search'] = search.trim();
      }

      final response = await _apiClient.get<dynamic>(
        AppConfig.eventsFriendsEndpoint,
        queryParameters: queryParameters,
      );

      return _parseEventListResponse(response);
    } on DioException {
      rethrow;
    } on Object catch (e) {
      throw DioException(
        requestOptions: RequestOptions(path: AppConfig.eventsFriendsEndpoint),
        error: e,
      );
    }
  }

  List<MyEventItemModel> _parseEventListResponse(Response<dynamic> response) {
    final statusCode = response.statusCode;
    final body = response.data;

    final isSuccess = statusCode == 200 || statusCode == 201;
    if (!isSuccess || body == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }

    final List<dynamic> items;
    if (body is List) {
      items = body;
    } else if (body is Map<String, dynamic>) {
      if (body['data'] is List) {
        items = body['data'] as List<dynamic>;
      } else if (body['items'] is List) {
        items = body['items'] as List<dynamic>;
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          error:
              'Unexpected Map response shape: no "data" or "items" '
              'array found. Payload: $body',
        );
      }
    } else {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error:
            'Unexpected response type: expected List or Map, '
            'got ${body.runtimeType}. Payload: $body',
      );
    }

    final result = <MyEventItemModel>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item is! Map<String, dynamic>) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          error:
              'Unexpected item shape at index $i: expected Map, '
              'got ${item.runtimeType}. Item: $item',
        );
      }
      result.add(MyEventItemModel.fromJson(item));
    }
    return List.unmodifiable(result);
  }
}
