import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:music_room/core/config/app_config.dart';

/// Service for securely storing and retrieving authentication tokens.
class TokenStorageService {
  TokenStorageService({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();
  static const String _tokenKey = AppConfig.tokenStorageKey;
  static const String _userKey = AppConfig.userStorageKey;

  final FlutterSecureStorage _secureStorage;

  /// Save JWT token securely
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  /// Retrieve JWT token
  Future<String?> getToken() async {
    return _secureStorage.read(key: _tokenKey);
  }

  /// Clear JWT token
  Future<void> clearToken() async {
    await _secureStorage.delete(key: _tokenKey);
  }

  /// Save user profile data
  Future<void> saveUserProfile(String userJson) async {
    await _secureStorage.write(key: _userKey, value: userJson);
  }

  /// Retrieve user profile data
  Future<String?> getUserProfile() async {
    return _secureStorage.read(key: _userKey);
  }

  /// Clear all auth data (logout)
  Future<void> clearAll() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _userKey);
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return false;
    }

    if (_isJwtExpired(token)) {
      await clearAll();
      return false;
    }

    return true;
  }

  bool _isJwtExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return true;
      }

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payloadMap = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = payloadMap['exp'];

      if (exp is! int) {
        return true;
      }

      final expiryTime = DateTime.fromMillisecondsSinceEpoch(
        exp * 1000,
        isUtc: true,
      );

      return DateTime.now().toUtc().isAfter(expiryTime);
    } on Object {
      return true;
    }
  }
}
