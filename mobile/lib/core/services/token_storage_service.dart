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
      if (kDebugMode) {
        debugPrint('[TokenStorage] Attempting to save token securely...');
      }
      await _secureStorage.write(key: _tokenKey, value: token);
      if (kDebugMode) {
        debugPrint('[TokenStorage] Token saved successfully.');
      }
    } catch (e) {
      if (kIsWeb) {
        if (kDebugMode) {
          debugPrint('[TokenStorage] Secure storage failed on Web, falling back to SharedPreferences: $e');
        }
        await _prefs.setString(_tokenKey, token);
      } else {
        if (kDebugMode) {
          debugPrint('[TokenStorage] Error saving token: $e');
        }
        rethrow;
      }
    }
  }

  /// Retrieve JWT token
  Future<String?> getToken() async {
    try {
      final secureToken = await _secureStorage.read(key: _tokenKey);
      if (secureToken != null) return secureToken;

      // If not in secure storage, check fallback on Web
      if (kIsWeb) {
        final prefsToken = _prefs.getString(_tokenKey);
        if (prefsToken != null) {
          // Attempt migration to secure storage for future requests
          try {
            await _secureStorage.write(key: _tokenKey, value: prefsToken);
            if (kDebugMode) {
              debugPrint('[TokenStorage] Migrated token from SharedPreferences to SecureStorage.');
            }
          } catch (_) {
            // Ignore migration errors (likely still on HTTP)
          }
          return prefsToken;
        }
      }
      return null;
    } catch (e) {
      if (kIsWeb) {
        return _prefs.getString(_tokenKey);
      }
      if (kDebugMode) {
        debugPrint('[TokenStorage] Error reading token: $e');
      }
      return null;
    }
  }

  /// Clear JWT token
  Future<void> clearToken() async {
    try {
      await _secureStorage.delete(key: _tokenKey);
    } catch (e) {
      if (kIsWeb) {
        await _prefs.remove(_tokenKey);
      } else {
        if (kDebugMode) {
          debugPrint('[TokenStorage] Error clearing token: $e');
        }
      }
    }
  }

  /// Save user profile data
  Future<void> saveUserProfile(String userJson) async {
    try {
      if (kDebugMode) {
        debugPrint('[TokenStorage] Attempting to save user profile securely...');
      }
      await _secureStorage.write(key: _userKey, value: userJson);
      if (kDebugMode) {
        debugPrint('[TokenStorage] User profile saved successfully.');
      }
    } catch (e) {
      if (kIsWeb) {
        if (kDebugMode) {
          debugPrint('[TokenStorage] Secure storage failed on Web, falling back to SharedPreferences: $e');
        }
        await _prefs.setString(_userKey, userJson);
      } else {
        if (kDebugMode) {
          debugPrint('[TokenStorage] Error saving user profile: $e');
        }
        rethrow;
      }
    }
  }

  /// Retrieve user profile data
  Future<String?> getUserProfile() async {
    try {
      final secureUser = await _secureStorage.read(key: _userKey);
      if (secureUser != null) return secureUser;

      // If not in secure storage, check fallback on Web
      if (kIsWeb) {
        final prefsUser = _prefs.getString(_userKey);
        if (prefsUser != null) {
          // Attempt migration to secure storage for future requests
          try {
            await _secureStorage.write(key: _userKey, value: prefsUser);
            if (kDebugMode) {
              debugPrint('[TokenStorage] Migrated user profile from SharedPreferences to SecureStorage.');
            }
          } catch (_) {
            // Ignore migration errors (likely still on HTTP)
          }
          return prefsUser;
        }
      }
      return null;
    } catch (e) {
      if (kIsWeb) {
        return _prefs.getString(_userKey);
      }
      if (kDebugMode) {
        debugPrint('[TokenStorage] Error reading user profile: $e');
      }
      return null;
    }
  }

  /// Clear all auth data (logout)
  Future<void> clearAll() async {
    try {
      await _secureStorage.delete(key: _tokenKey);
      await _secureStorage.delete(key: _userKey);
    } catch (e) {
      if (kIsWeb) {
        await _prefs.remove(_tokenKey);
        await _prefs.remove(_userKey);
      } else {
        if (kDebugMode) {
          debugPrint('[TokenStorage] Error clearing all storage: $e');
        }
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
