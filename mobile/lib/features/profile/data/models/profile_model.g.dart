// GENERATED CODE - manual implementation

part of 'profile_model.dart';

UserProfileModel _$UserProfileModelFromJson(Map<String, dynamic> json) {
  return UserProfileModel(
    id: json['id'] as String,
    username: json['username'] as String,
    subscriptionTier: json['subscriptionTier'] as String,
    email: json['email'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
    publicInfo: (json['publicInfo'] as Map<String, dynamic>?)
        ?.cast<String, dynamic>(),
    friendInfo: (json['friendInfo'] as Map<String, dynamic>?)
        ?.cast<String, dynamic>(),
    privateInfo: (json['privateInfo'] as Map<String, dynamic>?)
        ?.cast<String, dynamic>(),
    preferences: (json['preferences'] as Map<String, dynamic>?)
        ?.cast<String, dynamic>(),
    isFollowing: json['isFollowing'] as bool?,
    isFollowedBy: json['isFollowedBy'] as bool?,
    isFriend: json['isFriend'] as bool?,
  );
}

Map<String, dynamic> _$UserProfileModelToJson(UserProfileModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'email': instance.email,
      'avatarUrl': instance.avatarUrl,
      'subscriptionTier': instance.subscriptionTier,
      'publicInfo': instance.publicInfo,
      'friendInfo': instance.friendInfo,
      'privateInfo': instance.privateInfo,
      'preferences': instance.preferences,
      'isFollowing': instance.isFollowing,
      'isFollowedBy': instance.isFollowedBy,
      'isFriend': instance.isFriend,
    };
