import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class ClientMetaService {
  ClientMetaService({required SharedPreferences sharedPreferences})
    : _sharedPreferences = sharedPreferences;

  final SharedPreferences _sharedPreferences;

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
    // Generate a truly unique device ID using UUID v4
    // This ensures each installation gets a unique identifier,
    // unlike fingerprint-based approaches which can collide
    const uuid = Uuid();
    return uuid.v4();
  }
}
