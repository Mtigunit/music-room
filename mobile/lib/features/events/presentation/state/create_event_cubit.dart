import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:music_room/features/events/data/datasources/event_remote_datasource.dart';
import 'package:music_room/features/events/data/models/event_model.dart';
import 'package:music_room/features/events/data/models/track_model.dart';
import 'package:music_room/features/events/domain/entities/event_location.dart';
import 'package:music_room/features/events/domain/entities/event_tag.dart';
import 'package:music_room/features/events/presentation/validation/create_event_form_validator.dart';

abstract class CreateEventState {}

class CreateEventInitial extends CreateEventState {}

class CreateEventSubmitting extends CreateEventState {}

class CreateEventSuccess extends CreateEventState {
  CreateEventSuccess(this.eventId);

  final String eventId;
}

class CreateEventError extends CreateEventState {
  CreateEventError(this.message);

  final String message;
}

class CreateEventCubit extends Cubit<CreateEventState> {
  CreateEventCubit({required IEventRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource,
      super(CreateEventInitial());

  final IEventRemoteDataSource _remoteDataSource;

  Future<void> submitEvent({
    required String name,
    required String description,
    required XFile? coverImage,
    required List<EventTag> selectedTags,
    required List<TrackModel> selectedTracks,
    required String visibility,
    required String votingRule,
    required bool isRestricted,
    required EventLocation? allowedLocation,
    required double allowedRadius,
    required DateTime? startDate,
    required TimeOfDay? startTime,
    required DateTime? endDate,
    required TimeOfDay? endTime,
    required DateTime scheduledStartTime,
    List<String> playlistIds = const [],
  }) async {
    final input = CreateEventFormInput(
      name: name,
      description: description,
      selectedTags: selectedTags,
      selectedTracks: selectedTracks,
      visibility: visibility,
      votingRule: votingRule,
      isRestricted: isRestricted,
      allowedLocation: allowedLocation,
      allowedRadius: allowedRadius,
      startDate: startDate,
      startTime: startTime,
      endDate: endDate,
      endTime: endTime,
      scheduledStartTime: scheduledStartTime,
      playlistIds: playlistIds,
    );

    final validation = CreateEventFormValidator.validateForSubmit(input);
    if (!validation.isValid) {
      emit(
        CreateEventError(
          validation.firstError ?? 'Please check event details.',
        ),
      );
      return;
    }

    final preparedPayload = CreateEventFormValidator.preparePayload(input);

    final event = EventModel(
      name: preparedPayload.name,
      tags: preparedPayload.tags,
      visibility: preparedPayload.visibility,
      invitingOnly: preparedPayload.invitingOnly,
      description: preparedPayload.description,
      locationLat: preparedPayload.locationLat,
      locationLng: preparedPayload.locationLng,
      playlistIds: preparedPayload.playlistIds,
      tracks: preparedPayload.tracks,
      policies: preparedPayload.policies,
      startDate: preparedPayload.startDate,
    );

    emit(CreateEventSubmitting());

    try {
      final createdEventId = await _remoteDataSource.createEvent(
        event,
        coverImage,
      );

      emit(CreateEventSuccess(createdEventId));
    } on DioException catch (e) {
      emit(CreateEventError(_extractDioMessage(e)));
    } on Object {
      emit(CreateEventError('Unable to create event right now.'));
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

    return 'Unable to create event right now.';
  }
}
