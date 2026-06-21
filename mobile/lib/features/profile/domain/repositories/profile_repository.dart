import 'dart:typed_data';

import 'package:music_room/features/profile/domain/entities/profile_entity.dart';

/// Abstract repository interface for profile operations
abstract class ProfileRepository {
  /// Fetch the authenticated user's profile page data.
  Future<ProfilePageData> loadMyProfilePage();

  /// Fetch another user's public profile page data.
  Future<ProfilePageData> loadUserProfilePage(String userId);

  Future<ProfilePageData> followUser(String userId);

  Future<ProfilePageData> unfollowUser(String userId);

  Future<ProfilePageData> uploadMyAvatar(
    Uint8List bytes,
    String fileName,
  );

  Future<ProfilePageData> updateSubscription(String tier);
}
