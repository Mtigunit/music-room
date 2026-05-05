import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ClientMetaService {
  ClientMetaService({DeviceInfoPlugin? deviceInfoPlugin})
    : _deviceInfoPlugin = deviceInfoPlugin ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _deviceInfoPlugin;

  Map<String, String>? _headers;

  Future<Map<String, String>> getHeaders() async {
    if (_headers != null) {
      return _headers!;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final platform = _resolvePlatform();
    final deviceModel = await _resolveDeviceModel();

    _headers = <String, String>{
      'x-platform': platform,
      'x-device-model': deviceModel,
      'x-app-version': packageInfo.version,
    };

    return _headers!;
  }

  String _resolvePlatform() {
    return defaultTargetPlatform.name.toLowerCase();
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
