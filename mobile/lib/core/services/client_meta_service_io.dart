import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClientMetaService {
  ClientMetaService({
    required SharedPreferences sharedPreferences,
    DeviceInfoPlugin? deviceInfoPlugin,
  }) : _deviceInfoPlugin = deviceInfoPlugin ?? DeviceInfoPlugin(),
       _sharedPreferences = sharedPreferences;

  final DeviceInfoPlugin _deviceInfoPlugin;
  final SharedPreferences _sharedPreferences;

  Map<String, String>? _headers;
  String? _deviceId;

  static const String _deviceIdStorageKey = 'client_device_id';

  Future<Map<String, String>> getHeaders() async {
    if (_headers != null) {
      return _headers!;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final platform = _resolvePlatform();
    final deviceModel = await _resolveDeviceModel();
    final deviceId = await getDeviceId();

    _headers = <String, String>{
      'x-platform': platform,
      'x-device-model': deviceModel,
      'x-device-id': deviceId,
      'x-app-version': packageInfo.version,
    };

    return _headers!;
  }

  Future<String> getDeviceId() async {
    if (_deviceId != null && _deviceId!.isNotEmpty) {
      return _deviceId!;
    }

    final storedDeviceId = _sharedPreferences.getString(_deviceIdStorageKey);
    if (storedDeviceId != null && storedDeviceId.isNotEmpty) {
      _deviceId = storedDeviceId;
      return storedDeviceId;
    }

    final generatedDeviceId = await _generateDeviceId();
    _deviceId = generatedDeviceId;
    await _sharedPreferences.setString(_deviceIdStorageKey, generatedDeviceId);

    return generatedDeviceId;
  }

  String _resolvePlatform() {
    return defaultTargetPlatform.name.toLowerCase();
  }

  Future<String> _generateDeviceId() async {
    try {
      final deviceInfo = await _deviceInfoPlugin.deviceInfo;
      final fingerprintSeed = _buildFingerprintSeed(deviceInfo.data);
      if (fingerprintSeed.isNotEmpty) {
        return sha256.convert(utf8.encode(fingerprintSeed)).toString();
      }
    } on Object {
      // Fall back below.
    }

    final fallbackSeed = <String>[
      _resolvePlatform(),
      DateTime.now().microsecondsSinceEpoch.toString(),
    ].join('|');

    return sha256.convert(utf8.encode(fallbackSeed)).toString();
  }

  String _buildFingerprintSeed(Map<String, dynamic> deviceData) {
    final values = <Object?>[
      deviceData['brand'],
      deviceData['device'],
      deviceData['display'],
      deviceData['fingerprint'],
      deviceData['hardware'],
      deviceData['host'],
      deviceData['id'],
      deviceData['manufacturer'],
      deviceData['model'],
      deviceData['product'],
      deviceData['name'],
      deviceData['serialNumber'],
      deviceData['systemName'],
      deviceData['systemVersion'],
      deviceData['modelName'],
      deviceData['localizedModel'],
      deviceData['identifierForVendor'],
      deviceData['platform'],
      deviceData['userAgent'],
      deviceData['vendor'],
      deviceData['language'],
      deviceData['languages'],
      deviceData['hardwareConcurrency'],
      deviceData['maxTouchPoints'],
    ];

    return values
        .whereType<Object>()
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty && value != 'unknown')
        .join('|');
  }

  Future<String> _resolveDeviceModel() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        return androidInfo.model.isNotEmpty ? androidInfo.model : 'android';
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        return iosInfo.utsname.machine.isNotEmpty
            ? iosInfo.utsname.machine
            : 'ios';
      }

      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final macInfo = await _deviceInfoPlugin.macOsInfo;
        return macInfo.model.isNotEmpty ? macInfo.model : 'macos';
      }

      if (defaultTargetPlatform == TargetPlatform.windows) {
        final windowsInfo = await _deviceInfoPlugin.windowsInfo;
        return windowsInfo.productName.isNotEmpty
            ? windowsInfo.productName
            : 'windows';
      }

      if (defaultTargetPlatform == TargetPlatform.linux) {
        final linuxInfo = await _deviceInfoPlugin.linuxInfo;
        return linuxInfo.prettyName.isNotEmpty ? linuxInfo.prettyName : 'linux';
      }
    } on Object {
      // Fall back below.
    }

    return defaultTargetPlatform.name.toLowerCase();
  }
}
