import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:music_room/core/config/app_config.dart';
import 'package:music_room/features/auth/data/models/auth_model.dart';

final class GoogleAuthService {
  GoogleAuthService({
    required Dio dio,
  }) : _dio = dio;

  final Dio _dio;

  late final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool isInitialized = false;
  Completer<void>? _initializing;

  Future<void> initialize() async {
    if (isInitialized) {
      return;
    }

    final initializing = _initializing;
    if (initializing != null) {
      await initializing.future;
      return;
    }

    final completer = Completer<void>();
    _initializing = completer;

    try {
      if (kIsWeb) {
        await _googleSignIn.initialize(
          clientId: AppConfig.googleWebClientId,
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _googleSignIn.initialize(
          clientId: AppConfig.googleIosClientId,
          serverClientId: AppConfig.googleServerClientId,
        );
      } else {
        await _googleSignIn.initialize(
          serverClientId: AppConfig.googleServerClientId,
        );
      }

      isInitialized = true;
      completer.complete();
    } catch (error) {
      completer.completeError(error);
      rethrow;
    } finally {
      if (identical(_initializing, completer)) {
        _initializing = null;
      }
    }
  }

  Future<LoginResponse> authenticateMobile() async {
    if (kIsWeb) {
      throw const GoogleAuthException(
        'authenticateMobile cannot be used on Web.',
      );
    }

    try {
      await initialize();

      final account = await _googleSignIn.authenticate();
      final auth = account.authentication;

      final idToken = auth.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw const MissingGoogleIdTokenException();
      }

      return _exchangeTokenWithBackend(idToken);
    } on Object catch (e) {
      if (e is GoogleAuthException) {
        rethrow;
      }

      throw GoogleAuthException(e.toString());
    }
  }

  Future<LoginResponse> authenticateWeb(String idToken) async {
    final token = idToken.trim();

    if (token.isEmpty) {
      throw ArgumentError.value(
        idToken,
        'idToken',
        'must not be empty or whitespace',
      );
    }

    try {
      return await _exchangeTokenWithBackend(token);
    } on GoogleAuthException {
      rethrow;
    } catch (e, stackTrace) {
      Error.throwWithStackTrace(
        GoogleAuthException('Authentication failed: $e'),
        stackTrace,
      );
    }
  }

  Future<LoginResponse> _exchangeTokenWithBackend(
    String idToken,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        AppConfig.googleAuthEndpoint,
        data: {
          'idToken': idToken,
        },
      );

      final data = response.data;

      if (data == null) {
        throw const GoogleAuthException(
          'Invalid backend response.',
        );
      }

      final parsed = LoginResponse.fromJson(data);

      return parsed;
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map<String, dynamic>
          ? data['message']?.toString()
          : null;

      throw GoogleAuthException(
        message ?? 'Backend authentication failed.',
      );
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  /// Returns a raw Google ID token without exchanging it with the backend.
  /// Useful for linking flows where the backend expects the original idToken.
  Future<String> fetchIdToken() async {
    try {
      await initialize();

      final account = kIsWeb
          ? await _googleSignIn.attemptLightweightAuthentication()
          : await _googleSignIn.authenticate();

      if (account == null) {
        throw const GoogleAuthCancelledException();
      }

      final auth = account.authentication;
      final idToken = auth.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw const MissingGoogleIdTokenException();
      }

      return idToken;
    } on Object catch (e) {
      if (e is GoogleAuthException) rethrow;
      throw GoogleAuthException(e.toString());
    }
  }
}

class GoogleAuthException implements Exception {
  const GoogleAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GoogleAuthCancelledException extends GoogleAuthException {
  const GoogleAuthCancelledException() : super('Google sign-in cancelled.');
}

class MissingGoogleIdTokenException extends GoogleAuthException {
  const MissingGoogleIdTokenException()
    : super('Google did not return a valid ID token.');
}
