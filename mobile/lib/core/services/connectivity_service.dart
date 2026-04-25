import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Stream<bool> get isOnlineStream => _connectivity.onConnectivityChanged.map(
    _hasActiveConnection,
  );

  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return _hasActiveConnection(results);
  }

  bool _hasActiveConnection(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }
}
