import 'package:music_room/features/events/domain/entities/my_event_item_model.dart';

abstract class HomeRepository {
  Future<List<MyEventItemModel>> fetchExploreEvents({
    int page = 1,
    int limit = 20,
    List<String>? tags,
    String? status,
    String? search,
  });

  Future<List<MyEventItemModel>> fetchFriendsEvents({
    int page = 1,
    int limit = 20,
    List<String>? tags,
    String? status,
    String? search,
  });
}
