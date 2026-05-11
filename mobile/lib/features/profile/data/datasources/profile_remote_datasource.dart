import 'package:dio/dio.dart';
import 'package:music_room/core/config/app_config.dart';
import 'package:music_room/core/network/api_client.dart';
import 'package:music_room/features/profile/data/models/profile_model.dart';
import 'package:music_room/features/profile/domain/entities/profile_entity.dart';

// ─── Interface ──────────────────────────────────────────────────────────

abstract class IProfileRemoteDataSource {
  /// Fetch the authenticated user's own profile from GET /users/me
  Future<UserProfileModel> getMyProfile();

  /// Fetch another user's profile from GET /users/:id
  Future<UserProfileModel> getUserProfile(String userId);

  Future<UserProfileModel> updateMyProfile(ProfileUpdateRequest request);

  Future<UserProfileModel> updateMyUsername(String username);

  Future<UserProfileModel> uploadMyAvatar({
    required String filePath,
    required String fileName,
  });

  Future<void> followUser(String userId);

  Future<void> unfollowUser(String userId);

  Future<int> getFollowersCount(String userId);

  Future<int> getFollowingCount(String userId);
}

// ─── Implementation ─────────────────────────────────────────────────────

class ProfileRemoteDataSource implements IProfileRemoteDataSource {
  ProfileRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<UserProfileModel> getMyProfile() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        AppConfig.myProfileEndpoint,
      );

      return _parseProfileResponse(response, AppConfig.myProfileEndpoint);
    } on DioException {
      rethrow;
    } on Object catch (e) {
      throw DioException(
        requestOptions: RequestOptions(path: AppConfig.myProfileEndpoint),
        error: e,
      );
    }
  }

  @override
  Future<UserProfileModel> getUserProfile(String userId) async {
    try {
      final endpoint = '${AppConfig.userDetailEndpoint}/$userId';
      final response = await _apiClient.get<Map<String, dynamic>>(endpoint);

      return _parseProfileResponse(response, endpoint);
    } on DioException {
      rethrow;
    } on Object catch (e) {
      throw DioException(
        requestOptions: RequestOptions(
          path: '${AppConfig.userDetailEndpoint}/$userId',
        ),
        error: e,
      );
    }
  }

  @override
  Future<UserProfileModel> updateMyProfile(
    ProfileUpdateRequest request,
  ) async {
    try {
      const endpoint = '${AppConfig.myProfileEndpoint}/profile';
      final response = await _apiClient.patch<Map<String, dynamic>>(
        endpoint,
        data: request.toJson(),
      );

      return _parseProfileResponse(response, endpoint);
    } on DioException {
      rethrow;
    } on Object catch (error) {
      throw DioException(
        requestOptions: RequestOptions(
          path: '${AppConfig.myProfileEndpoint}/profile',
        ),
        error: error,
      );
    }
  }

  @override
  Future<UserProfileModel> updateMyUsername(String username) async {
    try {
      const endpoint = '${AppConfig.myProfileEndpoint}/username';
      final response = await _apiClient.patch<Map<String, dynamic>>(
        endpoint,
        data: <String, dynamic>{'username': username},
      );

      return _parseProfileResponse(response, endpoint);
    } on DioException {
      rethrow;
    } on Object catch (error) {
      throw DioException(
        requestOptions: RequestOptions(
          path: '${AppConfig.myProfileEndpoint}/username',
        ),
        error: error,
      );
    }
  }

  @override
  Future<UserProfileModel> uploadMyAvatar({
    required String filePath,
    required String fileName,
  }) async {
    try {
      const endpoint = '${AppConfig.myProfileEndpoint}/avatar';
      final formData = FormData.fromMap(
        <String, dynamic>{
          'avatar': await MultipartFile.fromFile(
            filePath,
            filename: fileName,
          ),
        },
      );

      final response = await _apiClient.post<Map<String, dynamic>>(
        endpoint,
        data: formData,
      );

      final statusCode = response.statusCode;
      final body = response.data;
      final isSuccess = statusCode == 200 || statusCode == 201;
      if (!isSuccess || body == null) {
        throw DioException(
          requestOptions: RequestOptions(path: endpoint),
          response: response,
          type: DioExceptionType.badResponse,
        );
      }

      return UserProfileModel.fromJson(body);
    } on DioException {
      rethrow;
    } on Object catch (error) {
      throw DioException(
        requestOptions: RequestOptions(path: AppConfig.myProfileEndpoint),
        error: error,
      );
    }
  }

  @override
  Future<void> followUser(String userId) async {
    final endpoint = '${AppConfig.userDetailEndpoint}/$userId/follow';

    try {
      final response = await _apiClient.post<Map<String, dynamic>>(endpoint);
      final statusCode = response.statusCode;
      final body = response.data;
      final isSuccess = statusCode == 200 || statusCode == 201;
      if (!isSuccess || body == null) {
        throw DioException(
          requestOptions: RequestOptions(path: endpoint),
          response: response,
          type: DioExceptionType.badResponse,
        );
      }
    } on DioException {
      rethrow;
    } on Object catch (error) {
      throw DioException(
        requestOptions: RequestOptions(path: endpoint),
        error: error,
      );
    }
  }

  @override
  Future<void> unfollowUser(String userId) async {
    final endpoint = '${AppConfig.userDetailEndpoint}/$userId/follow';

    try {
      final response = await _apiClient.delete<Map<String, dynamic>>(endpoint);
      final statusCode = response.statusCode;
      final body = response.data;
      final isSuccess = statusCode == 200 || statusCode == 201;
      if (!isSuccess || body == null) {
        throw DioException(
          requestOptions: RequestOptions(path: endpoint),
          response: response,
          type: DioExceptionType.badResponse,
        );
      }
    } on DioException {
      rethrow;
    } on Object catch (error) {
      throw DioException(
        requestOptions: RequestOptions(path: endpoint),
        error: error,
      );
    }
  }

  @override
  Future<int> getFollowersCount(String userId) {
    return _getRelationshipCount(
      '${AppConfig.userDetailEndpoint}/$userId/followers',
    );
  }

  @override
  Future<int> getFollowingCount(String userId) {
    return _getRelationshipCount(
      '${AppConfig.userDetailEndpoint}/$userId/following',
    );
  }

  // ─── Private helpers ────────────────────────────────────────────────────

  /// Parses a profile response from the API
  UserProfileModel _parseProfileResponse(
    Response<Map<String, dynamic>> response,
    String endpoint,
  ) {
    final statusCode = response.statusCode;
    final body = response.data;

    final isSuccess = statusCode == 200 || statusCode == 201;
    if (!isSuccess || body == null) {
      throw DioException(
        requestOptions: RequestOptions(path: endpoint),
        response: response,
        type: DioExceptionType.badResponse,
      );
    }

    try {
      return UserProfileModel.fromJson(body);
    } on Object catch (e) {
      throw DioException(
        requestOptions: RequestOptions(path: endpoint),
        error: e,
      );
    }
  }

  Future<int> _getRelationshipCount(String endpoint) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      endpoint,
      queryParameters: <String, dynamic>{'page': 1, 'limit': 1},
    );

    final body = response.data;
    final meta = body?['meta'];
    if (meta is Map<String, dynamic>) {
      final total = meta['total'];
      if (total is int) {
        return total;
      }
      if (total is num) {
        return total.toInt();
      }
    }

    return 0;
  }
}
