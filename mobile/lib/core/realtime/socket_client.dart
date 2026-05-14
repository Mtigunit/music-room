import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:music_room/core/config/app_config.dart';
import 'package:music_room/core/services/client_meta_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

typedef AccessTokenProvider = Future<String?> Function();

/// Low-level socket.io wrapper.
///
/// Exposes [onConnected] and [onDisconnected] as broadcast streams so that
/// feature modules can react to connection lifecycle events without registering
/// timing-sensitive `on('connect', ...)` callbacks.
///
/// Reconnection is driven externally — `ConnectivityService` is the single
/// owner of `reconnectWithAuth`. Feature modules must never call it directly.
class SocketClient {
  SocketClient({
    required String baseUrl,
    required AccessTokenProvider tokenProvider,
    required ClientMetaService clientMetaService,
  }) : _baseUrl = baseUrl,
       _tokenProvider = tokenProvider,
       _clientMetaService = clientMetaService;

  final String _baseUrl;
  final AccessTokenProvider _tokenProvider;
  final ClientMetaService _clientMetaService;
  io.Socket? _socket;

  // ── Public streams ────────────────────────────────────────────────────────

  final StreamController<void> _connectedController =
      StreamController<void>.broadcast();

  final StreamController<void> _disconnectedController =
      StreamController<void>.broadcast();

  final StreamController<Object> _connectErrorController =
      StreamController<Object>.broadcast();

  /// Fires every time the socket establishes (or re-establishes) a connection.
  Stream<void> get onConnected => _connectedController.stream;

  /// Fires every time the socket loses its connection.
  Stream<void> get onDisconnected => _disconnectedController.stream;

  /// Fires when a connection attempt fails.
  Stream<Object> get connectErrors => _connectErrorController.stream;

  // ── State ─────────────────────────────────────────────────────────────────

  bool get isConnected => _socket?.connected == true;

  // Queue of listeners waiting to be attached once the socket connects.
  final List<_PendingListener> _pendingListeners = [];

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> connect() async {
    final token = await _tokenProvider();
    if (token == null || token.isEmpty) return;

    _socket?.dispose();

    final extraHeaders = <String, dynamic>{};
    try {
      final clientHeaders = await _clientMetaService.getHeaders();
      extraHeaders.addAll(clientHeaders);
    } on Object catch (error) {
      if (AppConfig.isDebug) {
        debugPrint(
          '[SocketClient] Failed to load optional client metadata headers: '
          '$error',
        );
      }
    }

    _socket =
        io.io(
            _baseUrl,
            <String, dynamic>{
              'path': AppConfig.websocketPath,
              'transports': <String>['websocket'],
              'autoConnect': false,
              'reconnection': true,
              'reconnectionAttempts': 50,
              'reconnectionDelay': 1000,
              'auth': <String, dynamic>{'token': token},
              'extraHeaders': extraHeaders,
            },
          )
          ..on('connect', (_) {
            _connectedController.add(null);
            _attachPendingListeners();
          })
          ..on('disconnect', (_) {
            _disconnectedController.add(null);
          })
          ..on('connect_error', (dynamic error) {
            final connectError = error is Object ? error : 'connect_error';
            _connectErrorController.add(connectError);
          })
          ..on('reconnect_attempt', (_) async {
            final refreshedToken = await _tokenProvider();
            _socket?.auth = <String, dynamic>{'token': refreshedToken ?? ''};
          })
          ..connect();
  }

  /// Refreshes the auth token and reconnects.
  ///
  /// This must only be called by `ConnectivityService` (on internet restore)
  /// and by `app.dart` (on auth state changes). Feature modules must not
  /// call this directly.
  Future<void> reconnectWithAuth() async {
    if (_socket == null) {
      await connect();
      return;
    }

    final token = await _tokenProvider();
    _socket!
      ..auth = <String, dynamic>{'token': token ?? ''}
      ..connect();
  }

  void disconnect() {
    _socket?.disconnect();
  }

  Future<void> dispose() async {
    _socket?.dispose();
    _socket = null;
    _pendingListeners.clear();
    await _connectedController.close();
    await _disconnectedController.close();
    await _connectErrorController.close();
  }

  // ── Event subscription ────────────────────────────────────────────────────

  void on(String eventName, void Function(dynamic payload) handler) {
    if (_socket != null && _socket!.connected) {
      _socket?.on(eventName, handler);
    } else {
      _pendingListeners.add(_PendingListener(eventName, handler));
    }
  }

  void off(String eventName, [void Function(dynamic payload)? handler]) {
    _socket?.off(eventName, handler);
  }

  void emit(String eventName, Map<String, dynamic> payload) {
    _socket?.emit(eventName, payload);
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  void _attachPendingListeners() {
    for (final listener in _pendingListeners) {
      _socket?.on(listener.eventName, listener.handler);
    }
    _pendingListeners.clear();
  }
}

class _PendingListener {
  _PendingListener(this.eventName, this.handler);
  final String eventName;
  final void Function(dynamic payload) handler;
}
