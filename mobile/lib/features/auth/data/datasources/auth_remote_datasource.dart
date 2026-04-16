import 'package:dio/dio.dart';
import 'package:music_room/core/config/app_config.dart';
import 'package:music_room/core/network/api_client.dart';
import 'package:music_room/features/auth/data/models/auth_model.dart';

/// Remote data source for authentication API calls
abstract class IAuthRemoteDataSource {
  Future<SendOtpResponse> sendOtp(String email);
  Future<VerifyOtpResponse> verifyOtp(String email, String code);
  Future<RegisterResponse> register({
    required String email,
    required String username,
    required String password,
    required String emailVerificationToken,
  });
  Future<LoginResponse> login({
    required String identifier,
    required String password,
  });
  Future<UserProfile> getProfile();
}

/// Implementation of IAuthRemoteDataSource
class AuthRemoteDataSource implements IAuthRemoteDataSource {

  AuthRemoteDataSource({required ApiClient apiClient}) : _apiClient = apiClient;
  final ApiClient _apiClient;

  @override
  Future<SendOtpResponse> sendOtp(String email) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        AppConfig.sendOtpEndpoint,
        data: {'email': email},
      );

      if (response.statusCode == 201 && response.data != null) {
        return SendOtpResponse.fromJson(response.data!);
      }
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    } on DioException {
      rethrow;
    } catch (e) {
      throw DioException(
        requestOptions: RequestOptions(path: AppConfig.sendOtpEndpoint),
        error: e,
      );
    }
  }

  @override
  Future<VerifyOtpResponse> verifyOtp(String email, String code) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        AppConfig.verifyOtpEndpoint,
        data: {
          'email': email,
          'code': code,
        },
      );

      if (response.statusCode == 201 && response.data != null) {
        return VerifyOtpResponse.fromJson(response.data!);
      }
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    } on DioException {
      rethrow;
    } catch (e) {
      throw DioException(
        requestOptions: RequestOptions(path: AppConfig.verifyOtpEndpoint),
        error: e,
      );
    }
  }

  @override
  Future<RegisterResponse> register({
    required String email,
    required String username,
    required String password,
    required String emailVerificationToken,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        AppConfig.registerEndpoint,
        data: {
          'email': email,
          'username': username,
          'password': password,
          'emailVerificationToken': emailVerificationToken,
        },
      );

      if (response.statusCode == 201 && response.data != null) {
        return RegisterResponse.fromJson(response.data!);
      }
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    } on DioException {
      rethrow;
    } catch (e) {
      throw DioException(
        requestOptions: RequestOptions(path: AppConfig.registerEndpoint),
        error: e,
      );
    }
  }

  @override
  Future<LoginResponse> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        AppConfig.loginEndpoint,
        data: {
          'identifier': identifier,
          'password': password,
        },
      );

      if (response.statusCode == 201 && response.data != null) {
        return LoginResponse.fromJson(response.data!);
      }
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    } on DioException {
      rethrow;
    } catch (e) {
      throw DioException(
        requestOptions: RequestOptions(path: AppConfig.loginEndpoint),
        error: e,
      );
    }
  }

  @override
  Future<UserProfile> getProfile() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        AppConfig.profileEndpoint,
      );

      if (response.statusCode == 200 && response.data != null) {
        return UserProfile.fromJson(response.data!);
      }
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    } on DioException {
      rethrow;
    } catch (e) {
      throw DioException(
        requestOptions: RequestOptions(path: AppConfig.profileEndpoint),
        error: e,
      );
    }
  }
}
