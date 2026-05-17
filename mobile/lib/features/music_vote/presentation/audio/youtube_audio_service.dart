import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Resolves a YouTube `providerTrackId` to its highest-bitrate audio-only
/// stream URL.
///
/// This service is **internal** to `RoomAudioPlayer` and is never exposed to
/// the widget tree. It owns a single [YoutubeExplode] client which must be
/// released via [close] when the owning player is disposed.
///
/// All errors (restricted video, invalid id, network failure, timeout) are
/// swallowed and result in a `null` return value. Callers are expected to
/// treat `null` as a hard failure and stop playback gracefully.
class YoutubeAudioService {
  YoutubeAudioService();

  /// Per-client timeout. Each client in [_clientFallbacks] gets its own
  /// budget so a slow client cannot starve faster ones.
  static const Duration _perClientTimeout = Duration(seconds: 15);

  /// Fallback chain of YouTube API client signatures, tried one-by-one.
  ///
  /// Each client is attempted individually and the first one that returns
  /// playable audio streams wins. Ordering is chosen for maximum success
  /// rate against YouTube's current bot detection:
  ///
  /// 1. `tv`            — most permissive, broadest video compatibility.
  /// 2. `ios`           — reliable when Android signatures are flagged.
  /// 3. `androidMusic`  — optimised for music content.
  /// 4. `androidVr`     — historically works on age-gated / restricted.
  /// 5. `androidSdkless` — library default, kept as last resort.
  static final List<YoutubeApiClient> _clientFallbacks = [
    YoutubeApiClient.tv,
    YoutubeApiClient.ios,
    YoutubeApiClient.androidMusic,
    YoutubeApiClient.androidVr,
    YoutubeApiClient.androidSdkless,
  ];

  final YoutubeExplode _yt = YoutubeExplode();

  /// Resolves the highest-bitrate audio-only stream URL for [providerTrackId].
  ///
  /// Returns `null` on any failure. Failures are logged via [debugPrint]
  /// rather than thrown so the audio layer can stop cleanly without
  /// surfacing errors to the UI.
  Future<String?> resolveAudioStreamUrl(String providerTrackId) async {
    if (providerTrackId.isEmpty) {
      debugPrint(
        '[YoutubeAudioService] empty providerTrackId — skipping resolve',
      );
      return null;
    }

    if (kIsWeb) {
      debugPrint(
        '[YoutubeAudioService] running on Flutter Web — YouTube stream '
        'extraction is blocked by browser CORS. Run on Android/iOS/macOS '
        'to hear audio.',
      );
      return null;
    }

    for (final client in _clientFallbacks) {
      final clientName = _clientLabel(client);
      try {
        final manifest = await _yt.videos.streamsClient
            .getManifest(providerTrackId, ytClients: [client])
            .timeout(_perClientTimeout);

        final audioOnly = manifest.audioOnly;
        if (audioOnly.isEmpty) {
          debugPrint(
            '[YoutubeAudioService] $clientName returned no audio streams '
            'for $providerTrackId — trying next client',
          );
          continue;
        }

        return audioOnly.withHighestBitrate().url.toString();
      } on Object catch (e) {
        debugPrint(
          '[YoutubeAudioService] $clientName failed for $providerTrackId: $e',
        );
        continue;
      }
    }

    debugPrint(
      '[YoutubeAudioService] all ${_clientFallbacks.length} clients failed '
      'for $providerTrackId',
    );
    return null;
  }

  /// Human-readable label for a [YoutubeApiClient] used in log lines.
  String _clientLabel(YoutubeApiClient client) {
    final context = client.payload['context'];
    if (context is Map && context['client'] is Map) {
      final name = (context['client'] as Map)['clientName'];
      if (name is String && name.isNotEmpty) return name;
    }
    return 'unknown';
  }

  /// Releases the underlying [YoutubeExplode] HTTP client. Safe to call
  /// multiple times.
  void close() {
    try {
      _yt.close();
    } on Object catch (e) {
      debugPrint('[YoutubeAudioService] close error: $e');
    }
  }
}
