import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_room/features/music_vote/presentation/audio/stream_url_service.dart';

/// Wraps [AudioPlayer] and [AudioSession] to control event playback.
///
/// Implements race guards, lazy configuration, and track idempotency.
class RoomAudioPlayer {
  RoomAudioPlayer({
    required StreamUrlService streamUrlService,
  }) : _streamUrlService = streamUrlService;

  final StreamUrlService _streamUrlService;
  final AudioPlayer _player = AudioPlayer();

  bool _audioSessionInitialized = false;
  String? _loadedProviderTrackId;
  int _requestSeq = 0;

  /// Lazy initialization of the global audio session configuration.
  Future<void> _initAudioSession() async {
    if (_audioSessionInitialized) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _audioSessionInitialized = true;
    } on Object catch (e) {
      debugPrint('[RoomAudioPlayer] Failed to initialize AudioSession: $e');
    }
  }

  /// Resolves the stream URL if needed, seeks to [startPositionMs], and plays.
  ///
  /// Uses [_loadedProviderTrackId] for idempotency to avoid redundant fetches.
  Future<void> playTrack(String providerTrackId, int startPositionMs) async {
    final seq = ++_requestSeq;

    await _initAudioSession();
    if (seq != _requestSeq) return;

    if (_loadedProviderTrackId == providerTrackId) {
      // Idempotency: Track already loaded, just seek to position and play
      try {
        await _player.seek(Duration(milliseconds: startPositionMs));
        if (seq != _requestSeq) return;
        unawaited(_player.play());
      } on Object catch (e) {
        debugPrint('[RoomAudioPlayer] Idempotent play/seek error: $e');
      }
      return;
    }

    // Resolve URL for new track
    final url = await _streamUrlService.resolveAudioStreamUrl(providerTrackId);
    if (seq != _requestSeq) return;

    if (url == null) {
      debugPrint(
        '[RoomAudioPlayer] Stream url resolution returned null for: '
        '$providerTrackId',
      );
      await stop();
      return;
    }

    try {
      await _player.setUrl(url);
      if (seq != _requestSeq) return;

      _loadedProviderTrackId = providerTrackId;

      await _player.seek(Duration(milliseconds: startPositionMs));
      if (seq != _requestSeq) return;

      unawaited(_player.play());
    } on Object catch (e) {
      debugPrint('[RoomAudioPlayer] Error loading/playing stream URL: $e');
      await stop();
    }
  }

  /// Pauses playback.
  Future<void> pause() async {
    ++_requestSeq;
    try {
      await _player.pause();
    } on Object catch (e) {
      debugPrint('[RoomAudioPlayer] Error pausing player: $e');
    }
  }

  /// Seeks to [resumePositionMs] and resumes/plays the audio.
  Future<void> resume(int resumePositionMs) async {
    final seq = ++_requestSeq;
    try {
      await _player.seek(Duration(milliseconds: resumePositionMs));
      if (seq != _requestSeq) return;
      unawaited(_player.play());
    } on Object catch (e) {
      debugPrint('[RoomAudioPlayer] Error resuming player: $e');
    }
  }

  /// Stops playback and clears loaded track state.
  Future<void> stop() async {
    ++_requestSeq;
    _loadedProviderTrackId = null;
    try {
      await _player.stop();
    } on Object catch (e) {
      debugPrint('[RoomAudioPlayer] Error stopping player: $e');
    }
  }

  /// Clean up player resources and service streams.
  Future<void> dispose() async {
    ++_requestSeq;
    _loadedProviderTrackId = null;
    try {
      await _player.dispose();
    } on Object catch (e) {
      debugPrint('[RoomAudioPlayer] Error disposing player: $e');
    }
  }
}
