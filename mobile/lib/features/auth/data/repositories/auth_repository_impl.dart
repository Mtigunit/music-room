import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:music_room/core/error/failure.dart';
import 'package:music_room/core/services/google_auth_service.dart';
import 'package:music_room/core/services/token_storage_service.dart';
import 'package:music_room/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:music_room/features/auth/data/models/auth_model.dart';
import 'package:music_room/features/auth/domain/repositories/auth_repository.dart';

/// Implementation of AuthRepository
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required IAuthRemoteDataSource remoteDataSource,
    required TokenStorageService tokenStorage,
    required GoogleAuthService googleAuthService,
  }) : _remoteDataSource = remoteDataSource,
       _tokenStorage = tokenStorage,
       _googleAuthService = googleAuthService;
  final IAuthRemoteDataSource _remoteDataSource;
  final TokenStorageService _tokenStorage;
  final GoogleAuthService _googleAuthService;

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
  Future<(LoginResponse?, Failure?)> loginWithGoogle() async {
    try {
      final googleTokens = await _googleAuthService.authenticate();
      final response = await _remoteDataSource.loginWithGoogle(
        idToken: googleTokens.idToken,
      );

      await _tokenStorage.saveToken(response.accessToken);
      return (response, null);
    } on GoogleAuthException catch (e) {
      return (null, Failure(message: e.message));
    } on DioException catch (e) {
      return (null, _handleDioException(e));
    } on Object catch (e) {
      return (null, Failure(message: 'An unexpected error occurred: $e'));
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
  Future<(bool, Failure?)> sendPasswordResetOtp(String email) async {
    try {
      await _remoteDataSource.sendPasswordResetOtp(email);
      return (true, null);
    } on DioException catch (e) {
      return (false, _handleDioException(e));
    } on Object catch (e) {
      return (false, Failure(message: 'An unexpected error occurred: $e'));
    }
  }

  @override
  Future<(VerifyResetOtpResponse?, Failure?)> verifyPasswordResetOtp(
    String email,
    String code,
  ) async {
    try {
      final response = await _remoteDataSource.verifyPasswordResetOtp(
        email,
        code,
      );
      return (response, null);
    } on DioException catch (e) {
      return (null, _handleDioException(e));
    } on Object catch (e) {
      return (null, Failure(message: 'An unexpected error occurred: $e'));
    }
  }

  @override
  Future<(MessageResponse?, Failure?)> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    try {
      final response = await _remoteDataSource.resetPassword(
        email: email,
        resetToken: resetToken,
        newPassword: newPassword,
      );
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
    try {
      await _googleAuthService.signOut();
    } on Object {
      // Always clear local session even if Google sign-out fails.
    }

    await _tokenStorage.clearAll();
  }

  @override
  Future<bool> isAuthenticated() async {
    return _tokenStorage.isAuthenticated();
  }

  /// Convert DioException to user-friendly error messages
  Failure _handleDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const Failure(
          message: 'Network timeout. Please check your connection.',
        );

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;
        final requestPath = e.requestOptions.path;
        final message = switch (statusCode) {
          400 =>
            _extractErrorMessage(responseData) ??
                'Invalid input. Please check your entries.',
          401 =>
            // Debug: log full response data on 401 to help diagnose token/audience issues
            (() {
              if (kDebugMode) {
                try {
                  debugPrint(
                    'DEBUG: 401 response data for $requestPath: $responseData',
                  );
                } on Object catch (_) {}
              }

              return _extractErrorMessage(responseData) ??
                  _mapUnauthorizedFallback(requestPath);
            })(),
          409 =>
            _extractErrorMessage(responseData) ??
                'Email or username already exists.',
          500 => 'Server error. Please try again later.',
          _ => _extractErrorMessage(responseData) ?? 'An error occurred.',
        };
        return Failure(message: message);

      case DioExceptionType.cancel:
        return const Failure(message: 'Request cancelled.');

      case DioExceptionType.unknown:
        final errorText = e.error?.toString().toLowerCase() ?? '';
        if (errorText.contains('socketexception') ||
            errorText.contains('failed host lookup') ||
            errorText.contains('connection refused')) {
          return const Failure(
            message:
                'Cannot reach server. Verify API base URL and backend status.',
          );
        } else {
          return const Failure(
            message: 'Network error. Please check your connection.',
          );
        }

      case DioExceptionType.badCertificate:
        return const Failure(message: 'Security certificate error.');

      case DioExceptionType.connectionError:
        return const Failure(
          message: 'Failed to connect. Please check your connection.',
        );
    }
  }

  String _mapUnauthorizedFallback(String requestPath) {
    if (requestPath.contains('auth/login')) {
      return 'Invalid credentials. Please try again.';
    }

    if (requestPath.contains('auth/google')) {
      return 'Google authentication failed. Please try again.';
    }

    return 'Unauthorized. Please sign in again.';
  }

  /// Extract error message from API response
  String? _extractErrorMessage(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      if (responseData.containsKey('message')) {
        final message = _normalizeErrorValue(responseData['message']);
        if (message != null) {
          return message;
        }
      }
      if (responseData.containsKey('error')) {
        final error = _normalizeErrorValue(responseData['error']);
        if (error != null) {
          return error;
        }
      }
    }
    return null;
  }

  String? _normalizeErrorValue(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    if (value is List) {
      final parts = value
          .map(_normalizeErrorValue)
          .whereType<String>()
          .where((part) => part.isNotEmpty)
          .toList();

      if (parts.isEmpty) {
        return null;
      }

      return parts.join(', ');
    }

    if (value is Map<String, dynamic>) {
      if (value.containsKey('message')) {
        final message = _normalizeErrorValue(value['message']);
        if (message != null) {
          return message;
        }
      }

      if (value.containsKey('error')) {
        final error = _normalizeErrorValue(value['error']);
        if (error != null) {
          return error;
        }
      }
    }

    if (value == null) {
      return null;
    }

    final fallback = value.toString().trim();
    return fallback.isEmpty ? null : fallback;
  }
}
