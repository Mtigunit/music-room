import 'package:package_info_plus/package_info_plus.dart';

class ClientMetaService {
  Map<String, String>? _headers;

  Future<Map<String, String>> getHeaders() async {
    if (_headers != null) {
      return _headers!;
    }

    final packageInfo = await PackageInfo.fromPlatform();

    _headers = <String, String>{
      'x-platform': 'web',
      'x-device-model': 'web',
      'x-app-version': packageInfo.version,
    };

    return _headers!;
  }
}
