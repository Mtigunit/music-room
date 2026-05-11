import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemePreferenceService extends ChangeNotifier {
  ThemePreferenceService({required SharedPreferences sharedPreferences})
    : _sharedPreferences = sharedPreferences;

  final SharedPreferences _sharedPreferences;

  ThemeMode resolveThemeModeForUser(String? userId) {
    if (userId == null || userId.isEmpty) {
      return ThemeMode.system;
    }

    final storedPreference = _sharedPreferences.getString(
      _themePreferenceKey(userId),
    );

    switch (_normalizePreference(storedPreference)) {
      case 'LIGHT':
        return ThemeMode.light;
      case 'DARK':
        return ThemeMode.dark;
      case 'SYSTEM':
        return ThemeMode.system;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> saveThemePreferenceForUser(
    String userId,
    String? preference,
  ) async {
    if (userId.isEmpty) {
      return;
    }

    final key = _themePreferenceKey(userId);
    final normalizedPreference = _normalizePreference(preference);

    if (normalizedPreference == null) {
      await _sharedPreferences.remove(key);
    } else {
      await _sharedPreferences.setString(key, normalizedPreference);
    }

    notifyListeners();
  }

  String _themePreferenceKey(String userId) {
    return 'theme_preference_$userId';
  }

  String? _normalizePreference(String? preference) {
    final trimmed = preference?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    final upper = trimmed.toUpperCase();
    if (upper == 'LIGHT' || upper == 'DARK' || upper == 'SYSTEM') {
      return upper;
    }

    return null;
  }
}
