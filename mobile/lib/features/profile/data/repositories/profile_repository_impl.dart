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
  }) : _remoteDataSource = remoteDataSource,
       _eventRemoteDataSource = eventRemoteDataSource,
       _playlistRemoteDataSource = playlistRemoteDataSource,
       _themePreferenceService = themePreferenceService;

  final IProfileRemoteDataSource _remoteDataSource;
  final IEventRemoteDataSource _eventRemoteDataSource;
  final IPlaylistRemoteDataSource _playlistRemoteDataSource;
  final ThemePreferenceService _themePreferenceService;

  @override
  Future<ProfilePageData> loadMyProfilePage() async {
    final model = await _remoteDataSource.getMyProfile();
    final profile = model.toEntity();

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
  Future<ProfilePageData> uploadMyAvatar(
    String filePath,
    String fileName,
  ) async {
    await _remoteDataSource.uploadMyAvatar(
      filePath: filePath,
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
