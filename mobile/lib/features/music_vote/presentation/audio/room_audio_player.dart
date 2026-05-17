import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_room/features/music_vote/presentation/audio/youtube_audio_service.dart';

/// A thin wrapper around [AudioPlayer] (just_audio) that exposes the minimal
/// surface needed to drive playback as a side effect of `MusicVoteState`.
///
/// Lifecycle is owned by `RepositoryProvider` in the music vote view — this
/// class is intentionally never registered in the DI container.
///
/// Position is **never** read back from [AudioPlayer]. The caller computes
/// every playhead value from `currentTrackStartedAt` and
/// `pausedPlaybackPositionMs` and passes it in via [playTrack] / [resume].
///
/// All public methods are race-safe: each invocation increments an internal
/// request token and stale awaits self-cancel.
class RoomAudioPlayer {
  RoomAudioPlayer();

  final AudioPlayer _player = AudioPlayer();
  final YoutubeAudioService _youtube = YoutubeAudioService();

  /// Monotonically incremented on every public call. Any in-flight async work
  /// that captured an older value bails out before mutating player state.
  int _requestSeq = 0;

  /// The providerTrackId currently loaded into [_player], or `null` if the
  /// player has no URL loaded. Used to short-circuit re-extraction when the
  /// same track is re-played (e.g. PAUSED → PLAYING for the same id).
  String? _loadedProviderTrackId;

  /// Whether the global audio session has been configured. Configuration is
  /// idempotent but we guard so we only build a [AudioSessionConfiguration]
  /// once per process lifetime.
  bool _sessionConfigured = false;

  bool _disposed = false;

  Future<void> _ensureSessionConfigured() async {
    if (_sessionConfigured) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _sessionConfigured = true;
    } on Object catch (e) {
      debugPrint('[RoomAudioPlayer] audio session configure failed: $e');
    }
  }

  /// Loads (if needed) and plays [providerTrackId] starting at
  /// [startPositionMs].
  ///
  /// If the same [providerTrackId] is already loaded, the URL resolution
  /// and `setUrl` step is skipped — we just seek and play. Different id
  /// triggers a full reload.
  ///
  /// On URL-resolution failure this method logs the error, calls [stop],
  /// and returns silently — never throws.
  Future<void> playTrack(String providerTrackId, int startPositionMs) async {
    if (_disposed) return;
    final token = ++_requestSeq;

    await _ensureSessionConfigured();
    if (token != _requestSeq || _disposed) return;

    final position = Duration(
      milliseconds: startPositionMs < 0 ? 0 : startPositionMs,
    );

    try {
      if (_loadedProviderTrackId != providerTrackId) {
        final url = await _youtube.resolveAudioStreamUrl(providerTrackId);
        if (token != _requestSeq || _disposed) return;

        if (url == null) {
          debugPrint(
            '[RoomAudioPlayer] resolveAudioStreamUrl returned null for '
            '$providerTrackId — stopping playback',
          );
          await _stopInternal(token);
          return;
        }

        await _player.setUrl(url);
        if (token != _requestSeq || _disposed) return;
        _loadedProviderTrackId = providerTrackId;
      }

      await _player.seek(position);
      if (token != _requestSeq || _disposed) return;

      await _player.play();
    } on Object catch (e, stack) {
      debugPrint('[RoomAudioPlayer] playTrack error: $e');
      debugPrint('[RoomAudioPlayer] stack: $stack');
      await _stopInternal(token);
    }
  }

  /// Pauses playback. No-op if nothing is loaded.
  Future<void> pause() async {
    if (_disposed) return;
    final token = ++_requestSeq;
    try {
      await _player.pause();
      if (token != _requestSeq || _disposed) return;
    } on Object catch (e) {
      debugPrint('[RoomAudioPlayer] pause error: $e');
    }
  }

  /// Seeks to [resumePositionMs] then resumes playback.
  ///
  /// The caller is responsible for ensuring a track is already loaded
  /// (i.e. a previous successful [playTrack] for the relevant id).
  Future<void> resume(int resumePositionMs) async {
    if (_disposed) return;
    final token = ++_requestSeq;

    final position = Duration(
      milliseconds: resumePositionMs < 0 ? 0 : resumePositionMs,
    );

    try {
      await _player.seek(position);
      if (token != _requestSeq || _disposed) return;

      await _player.play();
    } on Object catch (e) {
      debugPrint('[RoomAudioPlayer] resume error: $e');
    }
  }

  /// Stops playback and clears the loaded track.
  Future<void> stop() async {
    if (_disposed) return;
    final token = ++_requestSeq;
    await _stopInternal(token);
  }

  Future<void> _stopInternal(int token) async {
    try {
      await _player.stop();
      if (token != _requestSeq || _disposed) return;
      _loadedProviderTrackId = null;
    } on Object catch (e) {
      debugPrint('[RoomAudioPlayer] stop error: $e');
    }
  }

  /// Releases the underlying audio player and YouTube client. Safe to call
  /// multiple times; subsequent calls are no-ops.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _requestSeq++;
    try {
      await _player.dispose();
    } on Object catch (e) {
      debugPrint('[RoomAudioPlayer] dispose player error: $e');
    }
    _youtube.close();
    _loadedProviderTrackId = null;
  }
}
