import 'package:music_room/core/config/app_config.dart';

/// Build a fully-qualified image URL from a backend-provided value.
///
/// Returns `null` when [value] is null/empty, returns the value unchanged
/// when it already starts with `http`, otherwise joins it with
/// `AppConfig.apiBaseUrl`.
String? resolveImageUrl(String? value) {
  if (value == null) return null;

  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('http')) return trimmed;

  final base = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
  final path = trimmed.replaceAll(RegExp('^/+'), '');
  return '$base/$path';
}
