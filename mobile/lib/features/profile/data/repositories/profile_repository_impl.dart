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
  }) : _remoteDataSource = remoteDataSource,
       _eventRemoteDataSource = eventRemoteDataSource,
       _playlistRemoteDataSource = playlistRemoteDataSource;

  final IProfileRemoteDataSource _remoteDataSource;
  final IEventRemoteDataSource _eventRemoteDataSource;
  final IPlaylistRemoteDataSource _playlistRemoteDataSource;

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

    return ProfilePageData(
      profile: profile,
      hostedRooms: hostedRooms
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
          .toList(growable: false),
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
}
