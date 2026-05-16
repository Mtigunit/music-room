import 'package:music_room/features/events/data/datasources/event_remote_datasource.dart';
import 'package:music_room/features/events/domain/entities/my_event_item_model.dart';

class EventRepository {
  EventRepository({required IEventRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  final IEventRemoteDataSource _remoteDataSource;

  Future<List<MyEventItemModel>> fetchPublicEvents({
    int page = 1,
    int limit = 20,
  }) {
    return _remoteDataSource.fetchPublicEvents(page: page, limit: limit);
  }
}
