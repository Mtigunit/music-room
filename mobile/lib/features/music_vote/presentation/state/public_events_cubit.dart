import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/features/events/data/datasources/event_remote_datasource.dart';
import 'package:music_room/features/events/domain/repositories/event_repository.dart';

abstract class PublicEventsState {}

class PublicEventsInitial extends PublicEventsState {}

class PublicEventsLoading extends PublicEventsState {}

class PublicEventsLoaded extends PublicEventsState {
  PublicEventsLoaded(this.events);

  final List<MyEventItemModel> events;
}

class PublicEventsError extends PublicEventsState {
  PublicEventsError(this.message);

  final String message;
}

class PublicEventsCubit extends Cubit<PublicEventsState> {
  PublicEventsCubit({required EventRepository eventRepository})
    : _eventRepository = eventRepository,
      super(PublicEventsInitial());

  final EventRepository _eventRepository;

  Future<void> fetchPublicEvents() async {
    emit(PublicEventsLoading());

    try {
      final events = await _eventRepository.fetchPublicEvents();
      if (isClosed) return;
      emit(PublicEventsLoaded(events));
    } on DioException catch (e) {
      if (isClosed) return;
      emit(PublicEventsError(_extractDioMessage(e)));
    } on Object {
      if (isClosed) return;
      emit(PublicEventsError('Unable to load public events right now.'));
    }
  }

  String _extractDioMessage(DioException exception) {
    final data = exception.response?.data;

    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }

      if (message is List) {
        final messages = message.whereType<String>().toList(growable: false);
        if (messages.isNotEmpty) {
          return messages.join('\n');
        }
      }
    }

    if (exception.message != null && exception.message!.trim().isNotEmpty) {
      return exception.message!;
    }

    return 'Unable to load public events right now.';
  }
}
