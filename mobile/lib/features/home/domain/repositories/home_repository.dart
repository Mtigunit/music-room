import 'package:music_room/features/events/data/datasources/event_remote_datasource.dart';

abstract class HomeRepository {
  Future<List<MyEventItemModel>> fetchExploreEvents({
    int page = 1,
    int limit = 20,
    String? tags,
    String? status,
    String? search,
  });

  Future<List<MyEventItemModel>> fetchFriendsEvents({
    int page = 1,
    int limit = 20,
    String? tags,
    String? status,
    String? search,
  });
}
