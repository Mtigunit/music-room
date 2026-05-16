import 'package:music_room/features/events/domain/entities/my_event_item_model.dart';
import 'package:music_room/features/home/data/datasources/home_remote_datasource.dart';
import 'package:music_room/features/home/domain/repositories/home_repository.dart';

class HomeRepositoryImpl implements HomeRepository {
  HomeRepositoryImpl({required IHomeRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  final IHomeRemoteDataSource _remoteDataSource;

  @override
  Future<List<MyEventItemModel>> fetchExploreEvents({
    int page = 1,
    int limit = 20,
    String? tags,
    String? status,
    String? search,
  }) {
    return _remoteDataSource.fetchExploreEvents(
      page: page,
      limit: limit,
      tags: tags,
      status: status,
      search: search,
    );
  }

  @override
  Future<List<MyEventItemModel>> fetchFriendsEvents({
    int page = 1,
    int limit = 20,
    String? tags,
    String? status,
    String? search,
  }) {
    return _remoteDataSource.fetchFriendsEvents(
      page: page,
      limit: limit,
      tags: tags,
      status: status,
      search: search,
    );
  }
}
