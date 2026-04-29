import 'package:dio/dio.dart';
import 'package:music_room/core/config/app_config.dart';
import 'package:music_room/core/network/api_client.dart';
import 'package:music_room/features/music_vote/data/models/event_detail_model.dart';
import 'package:music_room/features/music_vote/data/models/event_track_model.dart';

/// Contract for the Music Vote (Live Room) remote data source.
abstract class IMusicVoteRemoteDataSource {
  /// GET /events/{eventId} — fetch event details.
  Future<EventDetailModel> getEventDetails(String eventId);

  /// GET /events/{eventId}/tracks?page=&limit= — fetch queued tracks.
  Future<List<EventTrackModel>> getEventTracks(
    String eventId, {
    int page,
    int limit,
  });

  /// POST /events/{eventId}/tracks — append a track to the queue.
  Future<EventTrackModel> addTrackToEvent(
    String eventId,
    String providerTrackId,
  );
}

class MusicVoteRemoteDataSource implements IMusicVoteRemoteDataSource {
  MusicVoteRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<EventDetailModel> getEventDetails(String eventId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '${AppConfig.eventsEndpoint}/$eventId',
      );

      if (response.statusCode == 200 && response.data != null) {
        return EventDetailModel.fromJson(response.data!);
      }

      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    } on DioException {
      rethrow;
    } on Object catch (e) {
      throw DioException(
        requestOptions: RequestOptions(
          path: '${AppConfig.eventsEndpoint}/$eventId',
        ),
        error: e,
      );
    }
  }

  @override
  Future<List<EventTrackModel>> getEventTracks(
    String eventId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '${AppConfig.eventsEndpoint}/$eventId/tracks',
        queryParameters: {'page': page, 'limit': limit},
      );

      if (response.statusCode == 200 && response.data != null) {
        final rawData = response.data!['data'];
        if (rawData is List) {
          return rawData
              .map(
                (json) =>
                    EventTrackModel.fromJson(json as Map<String, dynamic>),
              )
              .toList();
        }
      }

      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    } on DioException {
      rethrow;
    } on Object catch (e) {
      throw DioException(
        requestOptions: RequestOptions(
          path: '${AppConfig.eventsEndpoint}/$eventId/tracks',
        ),
        error: e,
      );
    }
  }

  @override
  Future<EventTrackModel> addTrackToEvent(
    String eventId,
    String providerTrackId,
  ) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '${AppConfig.eventsEndpoint}/$eventId/tracks',
        data: {'providerTrackId': providerTrackId},
      );

      final isSuccess =
          response.statusCode == 200 || response.statusCode == 201;
      if (isSuccess && response.data != null) {
        return EventTrackModel.fromJson(response.data!);
      }

      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    } on DioException {
      rethrow;
    } on Object catch (e) {
      throw DioException(
        requestOptions: RequestOptions(
          path: '${AppConfig.eventsEndpoint}/$eventId/tracks',
        ),
        error: e,
      );
    }
  }
}
