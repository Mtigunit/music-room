import 'dart:typed_data';

import 'package:music_room/features/profile/domain/entities/profile_entity.dart';
import 'package:music_room/features/settings/domain/entities/settings_update_request.dart';

abstract class SettingsRepository {
  Future<ProfilePageData> loadMySettingsPage();

  Future<void> syncMyThemePreference();

  Future<ProfilePageData> updateMySettings(SettingsUpdateRequest request);

  Future<ProfilePageData> updateMyUsername(String username);

  Future<ProfilePageData> changeMyPassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<ProfilePageData> linkMyGoogleAccount(String userId);

  Future<ProfilePageData> unlinkMyGoogleAccount(String userId);

  Future<ProfilePageData> uploadMyAvatar(
    Uint8List bytes,
    String fileName,
  );

  Future<void> requestEmailUpdate({
    required String newEmail,
    required String password,
  });

  Future<ProfilePageData> verifyEmailUpdate({
    required String code,
  });
}
