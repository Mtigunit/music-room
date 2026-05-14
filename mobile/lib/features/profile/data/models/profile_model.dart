import 'package:music_room/features/profile/domain/entities/profile_entity.dart';

part 'profile_model.g.dart';

/// User profile model returned from both /users/me and /users/:id endpoints.
class UserProfileModel {
  const UserProfileModel({
    required this.id,
    required this.username,
    required this.subscriptionTier,
    this.email,
    this.avatarUrl,
    this.publicInfo,
    this.friendInfo,
    this.privateInfo,
    this.preferences,
    this.isFollowing,
    this.isFollowedBy,
    this.isFriend,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) =>
      _$UserProfileModelFromJson(json);

  final String id;
  final String username;
  final String? email;
  final String? avatarUrl;
  final String subscriptionTier;
  final Map<String, dynamic>? publicInfo;
  final Map<String, dynamic>? friendInfo;
  final Map<String, dynamic>? privateInfo;
  final Map<String, dynamic>? preferences;

  /// Present when viewing another user's profile
  final bool? isFollowing;
  final bool? isFollowedBy;
  final bool? isFriend;

  Map<String, dynamic> toJson() => _$UserProfileModelToJson(this);

  /// Convert to domain entity
  UserProfileEntity toEntity() {
    return UserProfileEntity(
      id: id,
      username: username,
      email: email,
      avatarUrl: avatarUrl,
      subscriptionTier: subscriptionTier,
      publicInfo: publicInfo,
      friendInfo: friendInfo,
      privateInfo: privateInfo,
      preferences: preferences,
      isFollowing: isFollowing ?? false,
      isFollowedBy: isFollowedBy ?? false,
      isFriend: isFriend ?? false,
    );
  }
}
