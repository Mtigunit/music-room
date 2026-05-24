import 'package:music_room/core/config/app_config.dart';

/// Build a fully-qualified image URL from a backend-provided value.
///
/// Returns `null` when [value] is null/empty, returns the value unchanged
/// when it already starts with `http`, otherwise joins it with
/// `AppConfig.apiBaseUrl`.
String? resolveImageUrl(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  if (value.startsWith('http')) return value;

  final base = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
  final path = value.replaceAll(RegExp('^/+'), '');
  return '$base/$path';
}
