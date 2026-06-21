import 'dart:typed_data';

import 'package:music_room/features/events/data/datasources/event_remote_datasource.dart';
import 'package:music_room/features/events/domain/entities/my_event_item_model.dart';
import 'package:music_room/features/playlist/data/datasources/playlist_remote_datasource.dart';
import 'package:music_room/features/playlist/domain/entities/playlist_entity.dart';
import 'package:music_room/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:music_room/features/profile/domain/entities/hosted_event_entity.dart';
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

    final hostedProfileRooms = hostedRooms
        .map(_toHostedEventEntity)
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
      hostedRooms: const <HostedEventEntity>[],
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

  @override
  Future<ProfilePageData> updateSubscription(String tier) async {
    await _remoteDataSource.updateSubscription(tier);
    return loadMyProfilePage();
  }

  HostedEventEntity _toHostedEventEntity(MyEventItemModel model) {
    final coverTrim = (model.coverImage ?? '').trim();
    final firstTrackTrim = (model.firstTrack ?? '').trim();
    final resolvedCover = coverTrim.isNotEmpty
        ? coverTrim
        : (firstTrackTrim.isNotEmpty ? firstTrackTrim : null);

    return HostedEventEntity(
      id: model.id,
      name: model.name,
      hostName: model.hostName,
      hostId: model.hostId,
      dateTime: model.startDate,
      status: model.status,
      coverImageAsset: resolvedCover,
      listenerCount: model.membersCount,
    );
  }
}
