import 'dart:typed_data';

import 'package:music_room/core/services/google_auth_service.dart';
import 'package:music_room/core/services/google_link_status_service.dart';
import 'package:music_room/core/services/theme_preference_service.dart';
import 'package:music_room/features/events/data/datasources/event_remote_datasource.dart';
import 'package:music_room/features/playlist/data/datasources/playlist_remote_datasource.dart';
import 'package:music_room/features/playlist/domain/entities/playlist_entity.dart';
import 'package:music_room/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:music_room/features/profile/domain/entities/profile_entity.dart';
import 'package:music_room/features/profile/domain/repositories/profile_repository.dart';

/// Implementation of ProfileRepository
class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({
    required IProfileRemoteDataSource remoteDataSource,
    required IEventRemoteDataSource eventRemoteDataSource,
    required IPlaylistRemoteDataSource playlistRemoteDataSource,
    required ThemePreferenceService themePreferenceService,
    required GoogleAuthService googleAuthService,
    required GoogleLinkStatusService googleLinkStatusService,
  }) : _remoteDataSource = remoteDataSource,
       _eventRemoteDataSource = eventRemoteDataSource,
       _playlistRemoteDataSource = playlistRemoteDataSource,
       _themePreferenceService = themePreferenceService,
       _googleAuthService = googleAuthService,
       _googleLinkStatusService = googleLinkStatusService;

  final IProfileRemoteDataSource _remoteDataSource;
  final IEventRemoteDataSource _eventRemoteDataSource;
  final IPlaylistRemoteDataSource _playlistRemoteDataSource;
  final ThemePreferenceService _themePreferenceService;
  final GoogleAuthService _googleAuthService;
  final GoogleLinkStatusService _googleLinkStatusService;

  @override
  Future<ProfilePageData> loadMyProfilePage() async {
    final model = await _remoteDataSource.getMyProfile();
    final profile = model.toEntity().copyWith(
      googleLinkStatus: _googleLinkStatusService.resolveStatusForUser(model.id),
    );

    final followersCountFuture = _remoteDataSource.getFollowersCount(
      profile.id,
    );
    final followingCountFuture = _remoteDataSource.getFollowingCount(
      profile.id,
    );
    final hostedRoomsFuture = _eventRemoteDataSource.fetchHostedEvents();
    final playlistsFuture = _playlistRemoteDataSource.fetchMyPlaylists();

    final followersCount = await followersCountFuture;
    final followingCount = await followingCountFuture;
    final hostedRooms = await hostedRoomsFuture;
    final playlists = await playlistsFuture;

    await _syncThemePreference(profile);

    final hostedProfileRooms = hostedRooms
        .map(
          (event) => ProfileRoomEntity(
            id: event.id,
            name: event.name,
            status: event.status,
            hostName: event.hostName,
            membersCount: event.membersCount,
            thumbnailUrl: event.coverImage,
          ),
        )
        .toList(growable: false);

    return ProfilePageData(
      profile: profile,
      hostedRooms: hostedProfileRooms,
      playlists: playlists,
      followersCount: followersCount,
      followingCount: followingCount,
    );
  }

  @override
  Future<void> syncMyThemePreference() async {
    final model = await _remoteDataSource.getMyProfile();
    final profile = model.toEntity();
    await _syncThemePreference(profile);
  }

  @override
  Future<ProfilePageData> loadUserProfilePage(String userId) async {
    final model = await _remoteDataSource.getUserProfile(userId);
    final profile = model.toEntity();
    final followersCountFuture = _remoteDataSource.getFollowersCount(userId);
    final followingCountFuture = _remoteDataSource.getFollowingCount(userId);

    final followersCount = await followersCountFuture;
    final followingCount = await followingCountFuture;

    return ProfilePageData(
      profile: profile,
      hostedRooms: const <ProfileRoomEntity>[],
      playlists: const <PlaylistEntity>[],
      followersCount: followersCount,
      followingCount: followingCount,
    );
  }

  @override
  Future<ProfilePageData> followUser(String userId) async {
    await _remoteDataSource.followUser(userId);
    return loadUserProfilePage(userId);
  }

  @override
  Future<ProfilePageData> unfollowUser(String userId) async {
    await _remoteDataSource.unfollowUser(userId);
    return loadUserProfilePage(userId);
  }

  @override
  Future<ProfilePageData> updateMyProfile(ProfileUpdateRequest request) async {
    await _remoteDataSource.updateMyProfile(request);
    return loadMyProfilePage();
  }

  @override
  Future<ProfilePageData> updateMyUsername(String username) async {
    await _remoteDataSource.updateMyUsername(username);
    return loadMyProfilePage();
  }

  @override
  Future<ProfilePageData> changeMyPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _remoteDataSource.changeMyPassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    return loadMyProfilePage();
  }

  /// Initiate email update by requesting an OTP to the new email address.
  @override
  Future<void> requestEmailUpdate({
    required String newEmail,
    required String password,
  }) async {
    await _remoteDataSource.requestEmailUpdate(
      newEmail: newEmail,
      password: password,
    );
  }

  /// Verify OTP for email update and refresh the local profile state.
  @override
  Future<ProfilePageData> verifyEmailUpdate({
    required String code,
  }) async {
    await _remoteDataSource.verifyEmailUpdate(code: code);
    return loadMyProfilePage();
  }

  @override
  Future<ProfilePageData> linkMyGoogleAccount(String userId) async {
    final idToken = await _googleAuthService.fetchIdToken();
    await _remoteDataSource.linkGoogleAccount(idToken: idToken);
    await _googleLinkStatusService.saveStatusForUser(
      userId,
      GoogleLinkStatus.linked,
    );
    return loadMyProfilePage();
  }

  @override
  Future<ProfilePageData> unlinkMyGoogleAccount(String userId) async {
    await _remoteDataSource.unlinkGoogleAccount();
    await _googleLinkStatusService.saveStatusForUser(
      userId,
      GoogleLinkStatus.unlinked,
    );
    return loadMyProfilePage();
  }

  @override
  Future<ProfilePageData> uploadMyAvatar(
    Uint8List bytes,
    String fileName,
  ) async {
    await _remoteDataSource.uploadMyAvatar(
      bytes: bytes,
      fileName: fileName,
    );
    return loadMyProfilePage();
  }

  Future<void> _syncThemePreference(UserProfileEntity profile) async {
    final uiTheme = profile.preferences?['uiTheme'];
    final themePreference = uiTheme is String ? uiTheme : null;
    await _themePreferenceService.saveThemePreferenceForUser(
      profile.id,
      themePreference,
    );
  }
}
