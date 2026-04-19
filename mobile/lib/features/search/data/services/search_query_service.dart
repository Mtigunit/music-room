import 'package:flutter/foundation.dart';

/// Manages shared search query state between Home and Search pages.
class SearchQueryService {
  /// ValueNotifier that holds the current search query.
  final ValueNotifier<String> queryNotifier = ValueNotifier<String>('');

  /// Get the current search query.
  String get currentQuery => queryNotifier.value;

  /// Set the current search query.
  set currentQuery(String query) {
    queryNotifier.value = query;
  }

  /// Clear the search query.
  void clearQuery() {
    queryNotifier.value = '';
  }

  /// Dispose resources.
  void dispose() {
    queryNotifier.dispose();
  }
}
