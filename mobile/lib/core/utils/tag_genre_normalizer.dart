import 'package:music_room/core/models/app_tags.dart';
import 'package:music_room/core/models/tag_option.dart';
import 'package:music_room/core/utils/tag_registry.dart';

class TagGenreNormalizer {
  const TagGenreNormalizer._();

  static const TagRegistry<String> _registry = AppTags.registry;

  static List<TagOption<String>> get allTags => _registry.tags;

  static List<String> get allValues =>
      allTags.map((tag) => tag.value).toList(growable: false);

  static List<String> get allDisplayLabels =>
      allTags.map((tag) => tag.displayLabel).toList(growable: false);

  static TagOption<String>? fromAny(Object? value) => _registry.fromAny(value);

  static String? toValue(Object? value) => _registry.toValue(value);

  static String? toDisplayLabel(Object? value) => _registry.toLabel(value);

  static List<String> normalizeValues(
    Iterable<Object?>? values, {
    int? limit,
  }) {
    return _registry.normalizeValues(values, limit: limit);
  }

  static List<String> toDisplayLabels(
    Iterable<Object?>? values, {
    int? limit,
  }) {
    return _registry.toLabels(values, limit: limit);
  }

  static String joinDisplayLabels(
    Iterable<Object?>? values, {
    String separator = ' · ',
    int? limit,
  }) {
    return _registry.joinLabels(values, separator: separator, limit: limit);
  }
}
