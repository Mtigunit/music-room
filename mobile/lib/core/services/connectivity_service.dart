import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:music_room/core/realtime/socket_client.dart';

/// Central service that monitors device connectivity and owns the global
/// socket reconnection lifecycle.
///
/// **Responsibilities:**
/// - Exposes [isOnlineStream] and [isOnline] for UI and feature modules.
/// - When the device comes back online, triggers
///   `SocketClient.reconnectWithAuth` so the global socket is restored.
///
/// **NOT responsible for:**
/// - Joining feature-specific rooms (per-feature via
///   `SocketClient.onConnected`).
/// - Re-fetching data (per-feature via their own connectivity subscription).
class ConnectivityService {
  ConnectivityService({
    required SocketClient socketClient,
    Connectivity? connectivity,
  }) : _socketClient = socketClient,
       _connectivity = connectivity ?? Connectivity() {
    _init();
  }

  final SocketClient _socketClient;
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  /// Emits `true` when any active network interface is available, `false`
  /// when all interfaces report [ConnectivityResult.none].
  Stream<bool> get isOnlineStream =>
      _connectivity.onConnectivityChanged.map(_hasActiveConnection);

  /// Checks the current connectivity state once.
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return _hasActiveConnection(results);
  }

  void dispose() {
    unawaited(_connectivitySub?.cancel());
  }

  // ── Private ───────────────────────────────────────────────────────────────

  void _init() {
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      if (_hasActiveConnection(results)) {
        // Internet is back — reconnect the global socket. Feature modules
        // will be notified via SocketClient.onConnected and can re-join their
        // rooms without performing any socket management themselves.
        unawaited(_socketClient.reconnectWithAuth());
      }
    });
  }

  bool _hasActiveConnection(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
