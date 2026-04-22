import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:music_room/features/events/data/datasources/event_remote_datasource.dart';
import 'package:music_room/features/events/data/models/event_model.dart';
import 'package:music_room/features/events/data/models/track_model.dart';
import 'package:music_room/features/events/domain/entities/event_location.dart';
import 'package:music_room/features/events/domain/entities/event_tag.dart';

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
    List<String> playlistIds = const [],
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      emit(CreateEventError('Event name is required.'));
      return;
    }

    final tags = selectedTags.toSet().toList(growable: false);
    if (tags.isEmpty) {
      emit(CreateEventError('Please select at least one tag.'));
      return;
    }

    if (tags.length > 3) {
      emit(CreateEventError('Please select up to 3 tags.'));
      return;
    }

    final mappedVisibility = _mapVisibility(visibility);
    if (mappedVisibility == null) {
      emit(CreateEventError('Invalid event visibility.'));
      return;
    }

    var policies = <EventPolicyModel>[];
    double? locationLat;
    double? locationLng;
    final isPrivate = mappedVisibility == 'PRIVATE';
    final invitingOnly = votingRule == 'Invited Only' || isPrivate;

    if (isRestricted) {
      if (allowedLocation == null) {
        emit(CreateEventError('Please set a location for restricted access.'));
        return;
      }

      final startAt = _combineDateAndTime(startDate, startTime);
      final endAt = _combineDateAndTime(endDate, endTime);

      if (startAt == null || endAt == null) {
        emit(
          CreateEventError(
            'Please select both start and end date/time for access rules.',
          ),
        );
        return;
      }

      if (!endAt.isAfter(startAt)) {
        emit(CreateEventError('End time must be after start time.'));
        return;
      }

      locationLat = allowedLocation.latitude;
      locationLng = allowedLocation.longitude;

      policies = [
        EventPolicyModel(
          policyType: 'GEOFENCE',
          config: {'distance': allowedRadius.round()},
        ),
        EventPolicyModel(
          policyType: 'TIME_WINDOW',
          config: {
            'startDate': startAt.toUtc().toIso8601String(),
            'endDate': endAt.toUtc().toIso8601String(),
          },
        ),
      ];
    }

    final event = EventModel(
      name: trimmedName,
      tags: tags,
      visibility: mappedVisibility,
      invitingOnly: invitingOnly,
      description: description.trim().isEmpty ? null : description.trim(),
      locationLat: locationLat,
      locationLng: locationLng,
      playlistIds: playlistIds.isEmpty ? null : playlistIds,
      tracks: selectedTracks.isEmpty ? null : selectedTracks,
      policies: policies,
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

  String? _mapVisibility(String visibility) {
    final normalized = visibility.trim().toLowerCase();
    if (normalized == 'public') {
      return 'PUBLIC';
    }
    if (normalized == 'private') {
      return 'PRIVATE';
    }

    return null;
  }

  DateTime? _combineDateAndTime(DateTime? date, TimeOfDay? time) {
    if (date == null || time == null) {
      return null;
    }

    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
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
