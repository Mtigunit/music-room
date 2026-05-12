import 'package:music_room/features/profile/domain/entities/profile_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoogleLinkStatusService {
  GoogleLinkStatusService({required SharedPreferences sharedPreferences})
    : _sharedPreferences = sharedPreferences;

  final SharedPreferences _sharedPreferences;

  GoogleLinkStatus resolveStatusForUser(String? userId) {
    if (userId == null || userId.isEmpty) {
      return GoogleLinkStatus.unknown;
    }

    final storedValue = _sharedPreferences.getString(_statusKey(userId));
    switch (storedValue) {
      case 'linked':
        return GoogleLinkStatus.linked;
      case 'unlinked':
        return GoogleLinkStatus.unlinked;
      default:
        return GoogleLinkStatus.unknown;
    }
  }

  Future<void> saveStatusForUser(
    String userId,
    GoogleLinkStatus status,
  ) async {
    if (userId.isEmpty) {
      return;
    }

    final key = _statusKey(userId);

    switch (status) {
      case GoogleLinkStatus.linked:
        await _sharedPreferences.setString(key, 'linked');
        return;
      case GoogleLinkStatus.unlinked:
        await _sharedPreferences.setString(key, 'unlinked');
        return;
      case GoogleLinkStatus.unknown:
        await _sharedPreferences.remove(key);
        return;
    }
  }

  String _statusKey(String userId) => 'google_link_status_$userId';
}
