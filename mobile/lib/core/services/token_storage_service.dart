import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_room/core/config/app_config.dart';

/// Service for securely storing and retrieving authentication tokens.
class TokenStorageService {
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;

  TokenStorageService({
    required FlutterSecureStorage secureStorage,
    required SharedPreferences prefs,
  })  : _secureStorage = secureStorage,
        _prefs = prefs;

  static const String _tokenKey = AppConfig.tokenStorageKey;
  static const String _userKey = AppConfig.userStorageKey;

  /// Save JWT token
  Future<void> saveToken(String token) async {
    try {
      if (kIsWeb) {
        // On Web, especially over HTTP, flutter_secure_storage fails.
        // Fallback to SharedPreferences for non-encrypted storage.
        debugPrint('[TokenStorage] Web detected, using SharedPreferences fallback.');
        await _prefs.setString(_tokenKey, token);
        return;
      }
      
      debugPrint('[TokenStorage] Attempting to save token securely...');
      await _secureStorage.write(key: _tokenKey, value: token);
      debugPrint('[TokenStorage] Token saved successfully.');
    } catch (e, stack) {
      debugPrint('[TokenStorage] Error saving token: $e');
      if (kIsWeb) {
        debugPrint('[TokenStorage] Falling back to SharedPreferences...');
        await _prefs.setString(_tokenKey, token);
      } else {
        debugPrint('[TokenStorage] Stack trace: $stack');
        rethrow;
      }
    }
  }

  /// Retrieve JWT token
  Future<String?> getToken() async {
    try {
      if (kIsWeb) {
        return _prefs.getString(_tokenKey);
      }
      return await _secureStorage.read(key: _tokenKey);
    } catch (e) {
      debugPrint('[TokenStorage] Error reading token: $e');
      if (kIsWeb) return _prefs.getString(_tokenKey);
      return null;
    }
  }

  /// Clear JWT token
  Future<void> clearToken() async {
    try {
      if (kIsWeb) {
        await _prefs.remove(_tokenKey);
        return;
      }
      await _secureStorage.delete(key: _tokenKey);
    } catch (e) {
      debugPrint('[TokenStorage] Error clearing token: $e');
      if (kIsWeb) await _prefs.remove(_tokenKey);
    }
  }

  /// Save user profile data
  Future<void> saveUserProfile(String userJson) async {
    try {
      if (kIsWeb) {
        await _prefs.setString(_userKey, userJson);
        return;
      }
      debugPrint('[TokenStorage] Attempting to save user profile securely...');
      await _secureStorage.write(key: _userKey, value: userJson);
      debugPrint('[TokenStorage] User profile saved successfully.');
    } catch (e, stack) {
      debugPrint('[TokenStorage] Error saving user profile: $e');
      if (kIsWeb) {
        await _prefs.setString(_userKey, userJson);
      } else {
        debugPrint('[TokenStorage] Stack trace: $stack');
        rethrow;
      }
    }
  }

  /// Retrieve user profile data
  Future<String?> getUserProfile() async {
    try {
      if (kIsWeb) {
        return _prefs.getString(_userKey);
      }
      return await _secureStorage.read(key: _userKey);
    } catch (e) {
      debugPrint('[TokenStorage] Error reading user profile: $e');
      if (kIsWeb) return _prefs.getString(_userKey);
      return null;
    }
  }

  /// Clear all auth data (logout)
  Future<void> clearAll() async {
    try {
      if (kIsWeb) {
        await _prefs.remove(_tokenKey);
        await _prefs.remove(_userKey);
        return;
      }
      await _secureStorage.delete(key: _tokenKey);
      await _secureStorage.delete(key: _userKey);
    } catch (e) {
      debugPrint('[TokenStorage] Error clearing all storage: $e');
      if (kIsWeb) {
        await _prefs.remove(_tokenKey);
        await _prefs.remove(_userKey);
      }
    }
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return false;
    }

    if (isJwtExpired(token)) {
      await clearAll();
      return false;
    }

    return true;
  }

  /// Check if a JWT token is expired
  bool isJwtExpired(String token) {
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
    } catch (e) {
      return true;
    }
  }
}
