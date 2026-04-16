import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:music_room/core/error/failure.dart';
import 'package:music_room/core/services/token_storage_service.dart';
import 'package:music_room/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:music_room/features/auth/data/models/auth_model.dart';
import 'package:music_room/features/auth/domain/repositories/auth_repository.dart';

/// Implementation of AuthRepository
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required IAuthRemoteDataSource remoteDataSource,
    required TokenStorageService tokenStorage,
  }) : _remoteDataSource = remoteDataSource,
       _tokenStorage = tokenStorage;
  final IAuthRemoteDataSource _remoteDataSource;
  final TokenStorageService _tokenStorage;

  @override
  Future<(LoginResponse?, Failure?)> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final response = await _remoteDataSource.login(
        identifier: identifier,
        password: password,
      );
      await _tokenStorage.saveToken(response.accessToken);
      return (response, null);
    } on DioException catch (e) {
      return (null, _handleDioException(e));
    } on Object catch (e) {
      return (null, Failure(message: 'An unexpected error occurred: $e'));
    }
  }

  @override
  Future<(bool, Failure?)> sendOtp(String email) async {
    try {
      await _remoteDataSource.sendOtp(email);
      return (true, null);
    } on DioException catch (e) {
      return (false, _handleDioException(e));
    } on Object catch (e) {
      return (false, Failure(message: 'An unexpected error occurred: $e'));
    }
  }

  @override
  Future<(VerifyOtpResponse?, Failure?)> verifyOtp(
    String email,
    String code,
  ) async {
    try {
      final response = await _remoteDataSource.verifyOtp(email, code);
      return (response, null);
    } on DioException catch (e) {
      return (null, _handleDioException(e));
    } on Object catch (e) {
      return (null, Failure(message: 'An unexpected error occurred: $e'));
    }
  }

  @override
  Future<(RegisterResponse?, Failure?)> register({
    required String email,
    required String username,
    required String password,
    required String emailVerificationToken,
  }) async {
    try {
      final response = await _remoteDataSource.register(
        email: email,
        username: username,
        password: password,
        emailVerificationToken: emailVerificationToken,
      );
      await _tokenStorage.saveToken(response.accessToken);
      return (response, null);
    } on DioException catch (e) {
      return (null, _handleDioException(e));
    } on Object catch (e) {
      return (null, Failure(message: 'An unexpected error occurred: $e'));
    }
  }

  @override
  Future<(UserProfile?, Failure?)> getProfile() async {
    try {
      final response = await _remoteDataSource.getProfile();
      await _tokenStorage.saveUserProfile(jsonEncode(response.toJson()));
      return (response, null);
    } on DioException catch (e) {
      return (null, _handleDioException(e));
    } on Object catch (e) {
      return (null, Failure(message: 'An unexpected error occurred: $e'));
    }
  }

  @override
  Future<void> logout() async {
    await _tokenStorage.clearAll();
  }

  @override
  Future<bool> isAuthenticated() async {
    return _tokenStorage.isAuthenticated();
  }

  /// Convert DioException to user-friendly error messages
  Failure _handleDioException(DioException e) {
    String message;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        message = 'Network timeout. Please check your connection.';

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;

        switch (statusCode) {
          case 400:
            message =
                _extractErrorMessage(responseData) ??
                'Invalid input. Please check your entries.';
          case 401:
            message = 'Invalid credentials. Please try again.';
          case 409:
            message =
                _extractErrorMessage(responseData) ??
                'Email or username already exists.';
          case 500:
            message = 'Server error. Please try again later.';
          default:
            message =
                _extractErrorMessage(responseData) ?? 'An error occurred.';
        }

      case DioExceptionType.cancel:
        message = 'Request cancelled.';

      case DioExceptionType.unknown:
        final errorText = e.error?.toString().toLowerCase() ?? '';
        if (errorText.contains('socketexception') ||
            errorText.contains('failed host lookup') ||
            errorText.contains('connection refused')) {
          message =
              'Cannot reach server. Verify API base URL and backend status.';
        } else {
          message = 'Network error. Please check your connection.';
        }

      case DioExceptionType.badCertificate:
        message = 'Security certificate error.';

      case DioExceptionType.connectionError:
        message = 'Failed to connect. Please check your connection.';
    }

    return Failure(message: message);
  }

  /// Extract error message from API response
  String? _extractErrorMessage(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      if (responseData.containsKey('message')) {
        return responseData['message'] as String;
      }
      if (responseData.containsKey('error')) {
        return responseData['error'] as String;
      }
    }
    return null;
  }
}
