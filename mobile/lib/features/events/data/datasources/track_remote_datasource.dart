import 'package:dio/dio.dart';
import 'package:music_room/core/config/app_config.dart';
import 'package:music_room/core/network/api_client.dart';
import 'package:music_room/features/events/data/models/track_model.dart';

// ignore: one_member_abstracts, reason: Interfaces for Repositories/Datasources often start with one method
abstract class ITrackRemoteDataSource {
  Future<List<TrackModel>> searchTracks(String query);
}

class TrackRemoteDataSource implements ITrackRemoteDataSource {
  TrackRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;
  final ApiClient _apiClient;

  @override
  Future<List<TrackModel>> searchTracks(String query) async {
    try {
      final response = await _apiClient.get<List<dynamic>>(
        AppConfig.searchTracksEndpoint,
        queryParameters: {'q': query},
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data!
            .map((json) => TrackModel.fromJson(json as Map<String, dynamic>))
            .toList();
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
        requestOptions: RequestOptions(path: AppConfig.searchTracksEndpoint),
        error: e,
      );
    }
  }
}
