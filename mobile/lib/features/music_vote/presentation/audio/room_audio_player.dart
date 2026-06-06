import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_room/features/music_vote/presentation/audio/stream_url_service.dart';

/// The real-time phase of the audio engine.
///
/// Consumers use this to gate UI (progress bar, play/pause button) on the
/// **actual** audio state instead of the expected state from the backend.
enum AudioPlaybackPhase {
  /// No audio loaded; player is idle.
  idle,

  /// A new track source is being fetched / buffered.  The UI should show a
  /// loading indicator and must NOT start the progress ticker.
  loading,

  /// Audio is actively playing through the speakers.
  playing,

  /// Audio was playing and is now paused.
  paused,

  /// An unrecoverable error occurred (URL resolution failed, codec error…).
  error,
}

/// Wraps [AudioPlayer] and [AudioSession] to control event playback.
///
/// Implements race guards, lazy configuration, track idempotency, and exposes
/// a [phaseStream] so callers know the *real* audio state.
class RoomAudioPlayer {
  RoomAudioPlayer({
    required StreamUrlService streamUrlService,
  }) : _streamUrlService = streamUrlService;

  final StreamUrlService _streamUrlService;
  final AudioPlayer _player = AudioPlayer();

  bool _audioSessionInitialized = false;
  String? _loadedProviderTrackId;
  int _requestSeq = 0;
  bool _disposed = false;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<void>? _becomingNoisySub;

  /// The provider ID of the currently loaded or loading track.
  String? get loadedProviderTrackId => _loadedProviderTrackId;

  // ── Phase stream ─────────────────────────────────────────────────────────

  final StreamController<AudioPlaybackPhase> _phaseController =
      StreamController<AudioPlaybackPhase>.broadcast();

  /// A broadcast stream of the real playback phase.
  ///
  /// The UI must gate progress tracking and control-button appearance on this
  /// stream rather than on the `playbackStatus` field from the socket.
  Stream<AudioPlaybackPhase> get phaseStream => _phaseController.stream;

  /// The last phase emitted.  Defaults to [AudioPlaybackPhase.idle].
  AudioPlaybackPhase _currentPhase = AudioPlaybackPhase.idle;
  AudioPlaybackPhase get currentPhase => _currentPhase;

  void _emitPhase(AudioPlaybackPhase phase) {
    _currentPhase = phase;
    if (!_phaseController.isClosed) {
      _phaseController.add(phase);
    }
  }

  // ── Audio session ────────────────────────────────────────────────────────

  /// Lazy initialization of the global audio session configuration.
  Future<void> _initAudioSession() async {
    if (_audioSessionInitialized || kIsWeb) {
      _audioSessionInitialized = true;
      return;
    }
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _interruptionSub ??= session.interruptionEventStream.listen((event) {
        if (_disposed || !event.begin) return;
        unawaited(pause());
      });
      _becomingNoisySub ??= session.becomingNoisyEventStream.listen((_) {
        if (_disposed) return;
        unawaited(pause());
      });
      _audioSessionInitialized = true;
    } on Object catch (e) {
      debugPrint('[RoomAudioPlayer] Failed to initialize AudioSession: $e');
    }
  }

  // ── Public API ───────────────────────────────────────────────────────────

  /// Resolves the stream URL if needed, seeks to [startPositionMs], and plays.
  ///
  /// If [autoPlay] is true, emits [AudioPlaybackPhase.loading] immediately,
  /// then [AudioPlaybackPhase.playing] once audio is actually emitting sound.
  /// If [autoPlay] is false, it silently preloads in the background to avoid
  /// blocking the UI, and stays in [AudioPlaybackPhase.paused].
  ///
  /// Returns `true` when the track is ready at [startPositionMs], or `false`
  /// when the load was aborted, superseded, or failed.
  Future<bool> loadTrack(
    String providerTrackId,
    int startPositionMs, {
    bool autoPlay = true,
  }) async {
    debugPrint(
      '🎵 [RoomAudioPlayer] loadTrack called for '
      '$providerTrackId at $startPositionMs (autoPlay: $autoPlay)',
    );
    final seq = ++_requestSeq;

    if (autoPlay) {
      // ── Immediately stop any in-progress audio ────────────────────────────
      _emitPhase(AudioPlaybackPhase.loading);
      try {
        await _player.stop();
      } on Object {
        // Best-effort stop
      }
    }

    await _initAudioSession();
    if (seq != _requestSeq) {
      debugPrint('🎵 [RoomAudioPlayer] loadTrack aborted: newer request (1)');
      return false;
    }

    if (_loadedProviderTrackId == providerTrackId) {
      debugPrint(
        '🎵 [RoomAudioPlayer] Track already loaded, '
        'seeking to $startPositionMs',
      );
      try {
        await _player.seek(Duration(milliseconds: startPositionMs));
        if (seq != _requestSeq) return false;

        if (autoPlay) {
          await _player.play();
          if (seq != _requestSeq) return false;
          _emitPhase(AudioPlaybackPhase.playing);
        } else {
          await _player.pause();
          if (seq != _requestSeq) return false;
          _emitPhase(AudioPlaybackPhase.paused);
        }
        return true;
      } on Object catch (e) {
        debugPrint('🎵 [RoomAudioPlayer] Idempotent load/seek error: $e');
        if (autoPlay && seq == _requestSeq) {
          _emitPhase(AudioPlaybackPhase.error);
        }
        return false;
      }
    }

    // Clear stale track id so a failed load doesn't leave a stale reference.
    _loadedProviderTrackId = null;

    debugPrint('🎵 [RoomAudioPlayer] Resolving URL for $providerTrackId...');
    final url = await _streamUrlService.resolveAudioStreamUrl(providerTrackId);
    if (seq != _requestSeq) {
      debugPrint('🎵 [RoomAudioPlayer] loadTrack aborted: newer request (2)');
      return false;
    }

    if (url == null) {
      debugPrint(
        '🎵 [RoomAudioPlayer] Stream url resolution returned null for: '
        '$providerTrackId',
      );
      if (autoPlay && seq == _requestSeq) {
        _emitPhase(AudioPlaybackPhase.error);
      }
      return false;
    }

    debugPrint('🎵 [RoomAudioPlayer] URL resolved. Setting URL on player...');
    try {
      await _player.setUrl(url);
      if (seq != _requestSeq) return false;

      _loadedProviderTrackId = providerTrackId;

      debugPrint('🎵 [RoomAudioPlayer] Seeking to $startPositionMs...');
      await _player.seek(
        Duration(milliseconds: startPositionMs),
      );
      if (seq != _requestSeq) return false;

      if (autoPlay) {
        debugPrint('🎵 [RoomAudioPlayer] Calling play()...');
        // Unawaited play to prevent hanging on Web without user interaction.
        // It will start playing when the browser allows it.
        unawaited(
          _player.play().catchError((Object e) {
            debugPrint('🎵 [RoomAudioPlayer] Play error: $e');
          }),
        );
        debugPrint('🎵 [RoomAudioPlayer] Playback requested successfully.');
        _emitPhase(AudioPlaybackPhase.playing);
      } else {
        debugPrint('🎵 [RoomAudioPlayer] Track preloaded and paused.');
        double? webOldVol;
        if (kIsWeb) {
          debugPrint('🎵 [RoomAudioPlayer] Forcing Web buffer...');
          webOldVol = _player.volume;
          await _player.setVolume(0);
          unawaited(_player.play().catchError((_) {}));
          try {
            await _player.playerStateStream
                .firstWhere(
                  (s) => s.processingState == ProcessingState.ready,
                )
                .timeout(const Duration(seconds: 15));
          } on Object catch (e) {
            debugPrint('🎵 [RoomAudioPlayer] Web buffer timeout/error: $e');
          }
        }
        if (seq != _requestSeq) return false;
        if (kIsWeb) {
          await _player.pause();
          await _player.seek(Duration(milliseconds: startPositionMs));
          await _player.setVolume(webOldVol!);
          debugPrint('🎵 [RoomAudioPlayer] Web buffer complete.');
        } else {
          await _player.pause();
        }
        _emitPhase(AudioPlaybackPhase.paused);
      }
      return true;
    } on Object catch (e) {
      debugPrint('🎵 [RoomAudioPlayer] Error loading/playing stream URL: $e');
      if (autoPlay && seq == _requestSeq) {
        _emitPhase(AudioPlaybackPhase.error);
      }
      return false;
    }
  }

  /// Pauses playback.
  Future<void> pause() async {
    debugPrint('🎵 [RoomAudioPlayer] pause called');
    ++_requestSeq;
    try {
      await _player.pause();
      _emitPhase(AudioPlaybackPhase.paused);
    } on Object catch (e) {
      debugPrint('[RoomAudioPlayer] Error pausing player: $e');
    }
  }

  /// Immediately silences the speaker and moves to the idle phase.
  ///
  /// Unlike `stop`, this does NOT clear the loaded track ID so a subsequent
  /// `loadTrack` for the same track benefits from the idempotency shortcut.
  Future<void> stopImmediately() async {
    ++_requestSeq;
    try {
      await _player.stop();
    } on Object catch (e) {
      debugPrint('[RoomAudioPlayer] Error in stopImmediately: $e');
    }
    _emitPhase(AudioPlaybackPhase.idle);
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
    _emitPhase(AudioPlaybackPhase.idle);
  }

  /// Clean up player resources and service streams.
  Future<void> dispose() async {
    _disposed = true;
    ++_requestSeq;
    _loadedProviderTrackId = null;
    await _interruptionSub?.cancel();
    await _becomingNoisySub?.cancel();
    _interruptionSub = null;
    _becomingNoisySub = null;
    _emitPhase(AudioPlaybackPhase.idle);
    await _phaseController.close();
    try {
      await _player.dispose();
    } on Object catch (e) {
      debugPrint('[RoomAudioPlayer] Error disposing player: $e');
    }
  }
}
