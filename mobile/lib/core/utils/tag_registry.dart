import 'package:music_room/core/models/tag_option.dart';

class TagRegistry<TValue extends Object> {
  const TagRegistry(this.tags);

  final List<TagOption<TValue>> tags;

  TagOption<TValue>? fromAny(Object? value) {
    if (value is TagOption<TValue>) {
      return value;
    }

    if (value is TValue) {
      for (final tag in tags) {
        if (tag.value == value) {
          return tag;
        }
      }
    }

    final normalized = _normalizeString(value);
    if (normalized == null) {
      return null;
    }

    final lowerNormalized = normalized.toLowerCase();
    final upperNormalized = normalized.toUpperCase();

    for (final tag in tags) {
      if (tag.label.toLowerCase() == lowerNormalized) {
        return tag;
      }

      if (tag.aliases.any((alias) => alias.toLowerCase() == lowerNormalized)) {
        return tag;
      }

      if (tag.value is String &&
          (tag.value as String).toUpperCase() == upperNormalized) {
        return tag;
      }
    }

    return null;
  }

  TValue? toValue(Object? value) => fromAny(value)?.value;

  String? toLabel(Object? value) => fromAny(value)?.label;

  List<TValue> normalizeValues(
    Iterable<Object?>? values, {
    int? limit,
  }) {
    if (limit != null && limit <= 0) {
      return <TValue>[];
    }

    if (values == null) {
      return <TValue>[];
    }

    final normalized = <TValue>[];
    final seen = <TValue>{};

    for (final value in values) {
      final normalizedValue = toValue(value);
      if (normalizedValue == null || !seen.add(normalizedValue)) {
        continue;
      }

      normalized.add(normalizedValue);

      if (limit != null && normalized.length >= limit) {
        break;
      }
    }

    return normalized;
  }

  List<String> toLabels(
    Iterable<Object?>? values, {
    int? limit,
  }) {
    return normalizeValues(
      values,
      limit: limit,
    ).map(toLabel).whereType<String>().toList(growable: false);
  }

  String joinLabels(
    Iterable<Object?>? values, {
    String separator = ' · ',
    int? limit,
  }) {
    final labels = toLabels(values, limit: limit);
    return labels.join(separator);
  }

  String? _normalizeString(Object? value) {
    if (value is! String) {
      return null;
    }

    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
