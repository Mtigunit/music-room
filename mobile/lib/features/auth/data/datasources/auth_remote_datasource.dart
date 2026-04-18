import 'package:dio/dio.dart';
import 'package:music_room/core/config/app_config.dart';
import 'package:music_room/core/network/api_client.dart';
import 'package:music_room/features/auth/data/models/auth_model.dart';

/// Remote data source for authentication API calls
abstract class IAuthRemoteDataSource {
  Future<SendOtpResponse> sendOtp(String email);
  Future<VerifyOtpResponse> verifyOtp(String email, String code);
  Future<SendOtpResponse> sendPasswordResetOtp(String email);
  Future<VerifyResetOtpResponse> verifyPasswordResetOtp(
    String email,
    String code,
  );
  Future<MessageResponse> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  });
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
    return _postAndMap(
      path: AppConfig.sendOtpEndpoint,
      data: {'email': email},
      expectedStatusCode: 201,
      parser: SendOtpResponse.fromJson,
    );
  }

  @override
  Future<VerifyOtpResponse> verifyOtp(String email, String code) async {
    return _postAndMap(
      path: AppConfig.verifyOtpEndpoint,
      data: {
        'email': email,
        'code': code,
      },
      expectedStatusCode: 201,
      parser: VerifyOtpResponse.fromJson,
    );
  }

  @override
  Future<SendOtpResponse> sendPasswordResetOtp(String email) async {
    return _postAndMap(
      path: AppConfig.forgotPasswordEndpoint,
      data: {'email': email},
      expectedStatusCode: 201,
      parser: SendOtpResponse.fromJson,
    );
  }

  @override
  Future<VerifyResetOtpResponse> verifyPasswordResetOtp(
    String email,
    String code,
  ) async {
    return _postAndMap(
      path: AppConfig.verifyResetOtpEndpoint,
      data: {
        'email': email,
        'code': code,
      },
      expectedStatusCode: 201,
      parser: VerifyResetOtpResponse.fromJson,
    );
  }

  @override
  Future<MessageResponse> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    return _postAndMap(
      path: AppConfig.resetPasswordEndpoint,
      data: {
        'email': email,
        'resetToken': resetToken,
        'newPassword': newPassword,
      },
      expectedStatusCode: 200,
      additionalSuccessStatusCodes: const {201},
      parser: MessageResponse.fromJson,
    );
  }

  @override
  Future<RegisterResponse> register({
    required String email,
    required String username,
    required String password,
    required String emailVerificationToken,
  }) async {
    return _postAndMap(
      path: AppConfig.registerEndpoint,
      data: {
        'email': email,
        'username': username,
        'password': password,
        'emailVerificationToken': emailVerificationToken,
      },
      expectedStatusCode: 201,
      parser: RegisterResponse.fromJson,
    );
  }

  @override
  Future<LoginResponse> login({
    required String identifier,
    required String password,
  }) async {
    return _postAndMap(
      path: AppConfig.loginEndpoint,
      data: {
        'identifier': identifier,
        'password': password,
      },
      expectedStatusCode: 201,
      parser: LoginResponse.fromJson,
    );
  }

  @override
  Future<UserProfile> getProfile() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        AppConfig.profileEndpoint,
      );

      return _parseResponse(
        response: response,
        expectedStatusCode: 200,
        parser: UserProfile.fromJson,
      );
    } on DioException {
      rethrow;
    } on Object catch (e) {
      throw _wrapAsDioException(path: AppConfig.profileEndpoint, error: e);
    }
  }

  Future<T> _postAndMap<T>({
    required String path,
    required Map<String, dynamic> data,
    required int expectedStatusCode,
    required T Function(Map<String, dynamic>) parser,
    Set<int> additionalSuccessStatusCodes = const {},
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        path,
        data: data,
      );

      return _parseResponse(
        response: response,
        expectedStatusCode: expectedStatusCode,
        additionalSuccessStatusCodes: additionalSuccessStatusCodes,
        parser: parser,
      );
    } on DioException {
      rethrow;
    } on Object catch (e) {
      throw _wrapAsDioException(path: path, error: e);
    }
  }

  T _parseResponse<T>({
    required Response<Map<String, dynamic>> response,
    required int expectedStatusCode,
    required T Function(Map<String, dynamic>) parser,
    Set<int> additionalSuccessStatusCodes = const {},
  }) {
    final statusCode = response.statusCode;
    final isExpectedStatus =
        statusCode == expectedStatusCode ||
        (statusCode != null &&
            additionalSuccessStatusCodes.contains(statusCode));

    if (isExpectedStatus && response.data != null) {
      return parser(response.data!);
    }

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
    );
  }

  DioException _wrapAsDioException({
    required String path,
    required Object error,
  }) {
    return DioException(
      requestOptions: RequestOptions(path: path),
      error: error,
    );
  }
}
