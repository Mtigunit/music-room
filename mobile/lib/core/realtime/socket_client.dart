import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:music_room/core/config/app_config.dart';
import 'package:music_room/core/services/client_meta_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

typedef AccessTokenProvider = Future<String?> Function();

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

  final StreamController<Object> _connectErrorController =
      StreamController<Object>.broadcast();

  Stream<Object> get connectErrors => _connectErrorController.stream;

  bool get isConnected => _socket?.connected == true;

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

    // Using cascade operator (..) to address 'cascade_invocations' lint
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
          ..on('connect_error', (dynamic error) {
            final connectError = error is Object ? error : 'connect_error';
            _connectErrorController.add(connectError);
          })
          ..on('reconnect_attempt', (_) async {
            final refreshedToken = await _tokenProvider();
            // Accessing the socket instance directly to update auth
            _socket?.auth = <String, dynamic>{'token': refreshedToken ?? ''};
          })
          ..connect();
  }

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

  void on(String eventName, void Function(dynamic payload) handler) {
    _socket?.on(eventName, handler);
  }

  void off(String eventName, [void Function(dynamic payload)? handler]) {
    _socket?.off(eventName, handler);
  }

  void emit(String eventName, Map<String, dynamic> payload) {
    _socket?.emit(eventName, payload);
  }

  void disconnect() {
    _socket?.disconnect();
  }

  Future<void> dispose() async {
    _socket?.dispose();
    _socket = null;
    await _connectErrorController.close();
  }
}
