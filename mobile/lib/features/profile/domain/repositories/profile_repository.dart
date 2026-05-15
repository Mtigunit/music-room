import 'dart:typed_data';

import 'package:music_room/features/profile/domain/entities/profile_entity.dart';

/// Abstract repository interface for profile operations
abstract class ProfileRepository {
  /// Fetch the authenticated user's profile page data.
  Future<ProfilePageData> loadMyProfilePage();

  /// Refresh the stored theme preference for the authenticated user.
  Future<void> syncMyThemePreference();

  /// Fetch another user's public profile page data.
  Future<ProfilePageData> loadUserProfilePage(String userId);

  Future<ProfilePageData> followUser(String userId);

  Future<ProfilePageData> unfollowUser(String userId);

  Future<ProfilePageData> updateMyProfile(ProfileUpdateRequest request);

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

  /// Initiate email update by requesting an OTP to the new email.
  Future<void> requestEmailUpdate({
    required String newEmail,
    required String password,
  });

  /// Verify OTP for email update and refresh the profile data.
  Future<ProfilePageData> verifyEmailUpdate({
    required String code,
  });
}
