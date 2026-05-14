import 'package:equatable/equatable.dart';
import 'package:music_room/features/playlist/domain/entities/playlist_entity.dart';

enum GoogleLinkStatus {
  unknown,
  linked,
  unlinked,
}

class ProfileRoomEntity extends Equatable {
  const ProfileRoomEntity({
    required this.id,
    required this.name,
    required this.status,
    required this.hostName,
    required this.membersCount,
    this.thumbnailUrl,
  });

  final String id;
  final String name;
  final String status;
  final String hostName;
  final int membersCount;
  final String? thumbnailUrl;

  bool get isLive => status.toUpperCase() == 'LIVE';

  @override
  List<Object?> get props => [
    id,
    name,
    status,
    hostName,
    membersCount,
    thumbnailUrl,
  ];
}

/// Domain entity for user profile
class UserProfileEntity extends Equatable {
  const UserProfileEntity({
    required this.id,
    required this.username,
    required this.subscriptionTier,
    this.email,
    this.avatarUrl,
    this.publicInfo,
    this.friendInfo,
    this.privateInfo,
    this.preferences,
    this.isFollowing = false,
    this.isFollowedBy = false,
    this.isFriend = false,
    this.googleLinkStatus = GoogleLinkStatus.unknown,
  });

  final String id;
  final String username;
  final String? email;
  final String? avatarUrl;
  final String subscriptionTier;
  final Map<String, dynamic>? publicInfo;
  final Map<String, dynamic>? friendInfo;
  final Map<String, dynamic>? privateInfo;
  final Map<String, dynamic>? preferences;

  /// Relationship indicators (for viewing other users)
  final bool isFollowing;
  final bool isFollowedBy;
  final bool isFriend;
  final GoogleLinkStatus googleLinkStatus;

  UserProfileEntity copyWith({
    GoogleLinkStatus? googleLinkStatus,
  }) {
    return UserProfileEntity(
      id: id,
      username: username,
      subscriptionTier: subscriptionTier,
      email: email,
      avatarUrl: avatarUrl,
      publicInfo: publicInfo,
      friendInfo: friendInfo,
      privateInfo: privateInfo,
      preferences: preferences,
      isFollowing: isFollowing,
      isFollowedBy: isFollowedBy,
      isFriend: isFriend,
      googleLinkStatus: googleLinkStatus ?? this.googleLinkStatus,
    );
  }

  /// Get short bio from publicInfo if available
  String? get shortBio {
    if (publicInfo is Map) {
      return publicInfo!['shortBio'] as String?;
    }
    return null;
  }

  /// Check if this is the current user's own profile
  bool get isSelf => email != null;

  @override
  List<Object?> get props => [
    id,
    username,
    email,
    avatarUrl,
    subscriptionTier,
    publicInfo,
    friendInfo,
    privateInfo,
    preferences,
    isFollowing,
    isFollowedBy,
    isFriend,
    googleLinkStatus,
  ];
}

class ProfilePageData extends Equatable {
  const ProfilePageData({
    required this.profile,
    required this.hostedRooms,
    required this.playlists,
    required this.followersCount,
    required this.followingCount,
  });

  final UserProfileEntity profile;
  final List<ProfileRoomEntity> hostedRooms;
  final List<PlaylistEntity> playlists;
  final int followersCount;
  final int followingCount;

  int get roomsCount => hostedRooms.length;

  @override
  List<Object?> get props => [
    profile,
    hostedRooms,
    playlists,
    followersCount,
    followingCount,
  ];
}

class ProfileUpdateRequest extends Equatable {
  const ProfileUpdateRequest({
    this.username,
    this.shortBio,
    this.location,
    this.dateOfBirth,
    this.physicalAddress,
    this.favoriteGenres,
    this.autoAcceptInvites,
    this.uiTheme,
  });

  final String? username;
  final String? shortBio;
  final String? location;
  final String? dateOfBirth;
  final String? physicalAddress;
  final List<String>? favoriteGenres;
  final bool? autoAcceptInvites;
  final String? uiTheme;

  bool hasChanges({String? currentUsername}) {
    final normalizedUsername = username?.trim();
    final hasUsernameChange =
        normalizedUsername != null &&
        normalizedUsername.isNotEmpty &&
        normalizedUsername != currentUsername?.trim();

    final hasProfileFieldChanges =
        (shortBio?.trim().isNotEmpty ?? false) ||
        (location?.trim().isNotEmpty ?? false) ||
        (dateOfBirth?.trim().isNotEmpty ?? false) ||
        (physicalAddress?.trim().isNotEmpty ?? false) ||
        (favoriteGenres?.isNotEmpty ?? false) ||
        autoAcceptInvites != null ||
        (uiTheme?.trim().isNotEmpty ?? false);

    return hasUsernameChange || hasProfileFieldChanges;
  }

  Map<String, dynamic> toJson() {
    final publicInfo = <String, dynamic>{};
    final friendInfo = <String, dynamic>{};
    final privateInfo = <String, dynamic>{};
    final preferences = <String, dynamic>{};

    final trimmedBio = shortBio?.trim();
    if (trimmedBio != null && trimmedBio.isNotEmpty) {
      publicInfo['shortBio'] = trimmedBio;
    }

    final trimmedLocation = location?.trim();
    if (trimmedLocation != null && trimmedLocation.isNotEmpty) {
      friendInfo['location'] = trimmedLocation;
    }

    final trimmedDateOfBirth = dateOfBirth?.trim();
    if (trimmedDateOfBirth != null && trimmedDateOfBirth.isNotEmpty) {
      privateInfo['dateOfBirth'] = trimmedDateOfBirth;
    }

    final trimmedPhysicalAddress = physicalAddress?.trim();
    if (trimmedPhysicalAddress != null && trimmedPhysicalAddress.isNotEmpty) {
      privateInfo['physicalAddress'] = trimmedPhysicalAddress;
    }

    if (favoriteGenres != null && favoriteGenres!.isNotEmpty) {
      preferences['favoriteGenres'] = favoriteGenres;
    }

    if (autoAcceptInvites != null) {
      preferences['autoAcceptInvites'] = autoAcceptInvites;
    }

    final trimmedUiTheme = uiTheme?.trim();
    if (trimmedUiTheme != null && trimmedUiTheme.isNotEmpty) {
      preferences['uiTheme'] = trimmedUiTheme;
    }

    final payload = <String, dynamic>{};
    if (publicInfo.isNotEmpty) {
      payload['publicInfo'] = publicInfo;
    }
    if (friendInfo.isNotEmpty) {
      payload['friendInfo'] = friendInfo;
    }
    if (privateInfo.isNotEmpty) {
      payload['privateInfo'] = privateInfo;
    }
    if (preferences.isNotEmpty) {
      payload['preferences'] = preferences;
    }

    return payload;
  }

  @override
  List<Object?> get props => [
    username,
    shortBio,
    location,
    dateOfBirth,
    physicalAddress,
    favoriteGenres,
    autoAcceptInvites,
    uiTheme,
  ];
}
