import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Service responsible for resolving YouTube stream URLs from the backend.
class StreamUrlService {
  const StreamUrlService({
    required Dio dio,
  }) : _dio = dio;

  final Dio _dio;

  /// Resolves the streaming audio URL for a given YouTube provider track ID.
  ///
  /// Calls `GET /playback/stream/{providerTrackId}`.
  /// Returns the stream URL as a string, or `null` if any network error,
  /// timeout, or bad response occurs.
  Future<String?> resolveAudioStreamUrl(String providerTrackId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'playback/stream/$providerTrackId',
        options: Options(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        final url = data['url'];
        if (url is String && url.isNotEmpty) {
          return url;
        }
      }

      debugPrint(
        '[StreamUrlService] Invalid response or missing URL for track: '
        '$providerTrackId',
      );
      return null;
    } on Object catch (e) {
      debugPrint('[StreamUrlService] Failed to resolve stream URL: $e');
      return null;
    }
  }
}
