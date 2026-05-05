import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClientMetaService {
  ClientMetaService({required SharedPreferences sharedPreferences})
    : _sharedPreferences = sharedPreferences;

  final SharedPreferences _sharedPreferences;

  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  Map<String, String>? _headers;
  String? _deviceId;

  static const String _deviceIdStorageKey = 'client_device_id';

  Future<Map<String, String>> getHeaders() async {
    if (_headers != null) {
      return _headers!;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final deviceId = await getDeviceId();

    _headers = <String, String>{
      'x-platform': 'web',
      'x-device-model': 'web',
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

  Future<String> _generateDeviceId() async {
    try {
      final browserInfo = await _deviceInfoPlugin.webBrowserInfo;
      final fingerprintSeed =
          <String>[
                browserInfo.appCodeName ?? '',
                browserInfo.appName ?? '',
                browserInfo.appVersion ?? '',
                browserInfo.language ?? '',
                browserInfo.platform ?? '',
                browserInfo.product ?? '',
                browserInfo.productSub ?? '',
                browserInfo.userAgent ?? '',
                browserInfo.vendor ?? '',
                browserInfo.vendorSub ?? '',
                browserInfo.hardwareConcurrency?.toString() ?? '',
                browserInfo.maxTouchPoints?.toString() ?? '',
                browserInfo.deviceMemory?.toString() ?? '',
                browserInfo.languages?.join(',') ?? '',
              ]
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .join('|');

      if (fingerprintSeed.isNotEmpty) {
        return sha256.convert(utf8.encode(fingerprintSeed)).toString();
      }
    } on Object {
      // Fall back below.
    }

    final fallbackSeed = <String>[
      'web',
      DateTime.now().microsecondsSinceEpoch.toString(),
    ].join('|');

    return sha256.convert(utf8.encode(fallbackSeed)).toString();
  }
}
