import 'package:flutter/material.dart';
import 'package:music_room/features/events/data/models/event_model.dart';
import 'package:music_room/features/events/data/models/track_model.dart';
import 'package:music_room/features/events/domain/entities/event_location.dart';
import 'package:music_room/features/events/domain/entities/event_tag.dart';

class CreateEventValidationField {
  static const name = 'name';
  static const tags = 'tags';
  static const visibility = 'visibility';
  static const tracks = 'tracks';
  static const allowedLocation = 'allowedLocation';
  static const accessWindow = 'accessWindow';
  static const allowedRadius = 'allowedRadius';
}

class CreateEventFormInput {
  const CreateEventFormInput({
    required this.name,
    required this.description,
    required this.selectedTags,
    required this.selectedTracks,
    required this.visibility,
    required this.votingRule,
    required this.isRestricted,
    required this.allowedLocation,
    required this.allowedRadius,
    required this.startDate,
    required this.startTime,
    required this.endDate,
    required this.endTime,
    required this.scheduledStartTime,
    this.playlistIds = const [],
  });

  final String name;
  final String description;
  final List<EventTag> selectedTags;
  final List<TrackModel> selectedTracks;
  final String visibility;
  final String votingRule;
  final bool isRestricted;
  final EventLocation? allowedLocation;
  final double allowedRadius;
  final DateTime? startDate;
  final TimeOfDay? startTime;
  final DateTime? endDate;
  final TimeOfDay? endTime;
  final DateTime scheduledStartTime;
  final List<String> playlistIds;
}

class CreateEventValidationResult {
  const CreateEventValidationResult({required this.errors});

  final Map<String, String> errors;

  bool get isValid => errors.isEmpty;

  String? get firstError {
    if (errors.isEmpty) {
      return null;
    }

    return errors.values.first;
  }
}

class CreateEventPreparedPayload {
  const CreateEventPreparedPayload({
    required this.name,
    required this.description,
    required this.tags,
    required this.visibility,
    required this.invitingOnly,
    required this.locationLat,
    required this.locationLng,
    required this.policies,
    required this.tracks,
    required this.playlistIds,
    required this.startDate,
  });

  final String name;
  final String? description;
  final List<EventTag> tags;
  final String visibility;
  final bool invitingOnly;
  final double? locationLat;
  final double? locationLng;
  final List<EventPolicyModel> policies;
  final List<TrackModel>? tracks;
  final List<String>? playlistIds;
  final String startDate;
}

class CreateEventFormValidator {
  static const int detailsStep = 0;
  static const int genreStep = 1;
  static const int musicStep = 2;
  static const int accessStep = 3;

  static CreateEventValidationResult validateStep(
    CreateEventFormInput input,
    int step,
  ) {
    final errors = <String, String>{};

    if (step == detailsStep) {
      errors.addAll(_validateDetails(input));
    } else if (step == genreStep) {
      errors.addAll(_validateTags(input));
    } else if (step == musicStep) {
      errors.addAll(_validateTracks(input));
    } else if (step == accessStep) {
      errors.addAll(_validateAccess(input));
    }

    return CreateEventValidationResult(errors: errors);
  }

  static CreateEventValidationResult validateForSubmit(
    CreateEventFormInput input,
  ) {
    final errors = <String, String>{
      ..._validateDetails(input),
      ..._validateTags(input),
      ..._validateTracks(input),
      ..._validateAccess(input),
    };

    return CreateEventValidationResult(errors: errors);
  }

  static CreateEventPreparedPayload preparePayload(CreateEventFormInput input) {
    final mappedVisibility = _mapVisibility(input.visibility)!;
    final invitingOnly =
        input.votingRule == 'Invited Only' || mappedVisibility == 'PRIVATE';

    final normalizedTracks = _normalizedTracks(input.selectedTracks);
    final normalizedPlaylistIds = _normalizedPlaylistIds(input.playlistIds);

    var policies = <EventPolicyModel>[];
    double? locationLat;
    double? locationLng;

    if (input.isRestricted) {
      final startAt = _combineDateAndTime(input.startDate, input.startTime)!;
      final endAt = _combineDateAndTime(input.endDate, input.endTime)!;

      locationLat = input.allowedLocation!.latitude;
      locationLng = input.allowedLocation!.longitude;

      policies = [
        EventPolicyModel(
          policyType: 'GEOFENCE',
          config: {'distance': input.allowedRadius.round()},
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

    final trimmedDescription = input.description.trim();

    return CreateEventPreparedPayload(
      name: input.name.trim(),
      description: trimmedDescription.isEmpty ? null : trimmedDescription,
      tags: input.selectedTags.toSet().toList(growable: false),
      visibility: mappedVisibility,
      invitingOnly: invitingOnly,
      locationLat: locationLat,
      locationLng: locationLng,
      policies: policies,
      tracks: normalizedTracks,
      playlistIds: normalizedPlaylistIds,
      startDate: input.scheduledStartTime.toUtc().toIso8601String(),
    );
  }

  static Map<String, String> _validateDetails(CreateEventFormInput input) {
    final errors = <String, String>{};

    if (input.name.trim().isEmpty) {
      errors[CreateEventValidationField.name] = 'Event name is required.';
    }

    return errors;
  }

  static Map<String, String> _validateTags(CreateEventFormInput input) {
    final errors = <String, String>{};
    final tags = input.selectedTags.toSet().toList(growable: false);

    if (tags.isEmpty) {
      errors[CreateEventValidationField.tags] =
          'Please select at least one tag.';
      return errors;
    }

    if (tags.length > 3) {
      errors[CreateEventValidationField.tags] = 'Please select up to 3 tags.';
    }

    return errors;
  }

  static Map<String, String> _validateTracks(CreateEventFormInput input) {
    final errors = <String, String>{};

    final hasInvalidTrack = input.selectedTracks.any(
      (track) => track.providerTrackId.trim().isEmpty,
    );

    if (hasInvalidTrack) {
      errors[CreateEventValidationField.tracks] =
          'One or more selected tracks are invalid. '
          'Please remove and re-add them.';
    }

    return errors;
  }

  static Map<String, String> _validateAccess(CreateEventFormInput input) {
    final errors = <String, String>{};

    final mappedVisibility = _mapVisibility(input.visibility);
    if (mappedVisibility == null) {
      errors[CreateEventValidationField.visibility] =
          'Please choose a valid visibility.';
      return errors;
    }

    if (!input.isRestricted) {
      return errors;
    }

    if (input.allowedLocation == null) {
      errors[CreateEventValidationField.allowedLocation] =
          'Please set a location for restricted access.';
    }

    if (!input.allowedRadius.isFinite || input.allowedRadius <= 0) {
      errors[CreateEventValidationField.allowedRadius] =
          'Geofence radius must be greater than 0.';
    }

    final startAt = _combineDateAndTime(input.startDate, input.startTime);
    final endAt = _combineDateAndTime(input.endDate, input.endTime);

    if (startAt == null || endAt == null) {
      errors[CreateEventValidationField.accessWindow] =
          'Please select both start and end date/time for access rules.';
      return errors;
    }

    if (!endAt.isAfter(startAt)) {
      errors[CreateEventValidationField.accessWindow] =
          'End time must be after start time.';
    }

    return errors;
  }

  static String? _mapVisibility(String visibility) {
    final normalized = visibility.trim().toLowerCase();
    if (normalized == 'public') {
      return 'PUBLIC';
    }

    if (normalized == 'private') {
      return 'PRIVATE';
    }

    return null;
  }

  static DateTime? _combineDateAndTime(DateTime? date, TimeOfDay? time) {
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

  static List<TrackModel>? _normalizedTracks(List<TrackModel> selectedTracks) {
    if (selectedTracks.isEmpty) {
      return null;
    }

    final seenIds = <String>{};
    final normalized = <TrackModel>[];

    for (final track in selectedTracks) {
      final id = track.providerTrackId.trim();
      if (id.isEmpty || seenIds.contains(id)) {
        continue;
      }

      seenIds.add(id);
      normalized.add(track);
    }

    return normalized.isEmpty ? null : normalized;
  }

  static List<String>? _normalizedPlaylistIds(List<String> playlistIds) {
    if (playlistIds.isEmpty) {
      return null;
    }

    final normalized = playlistIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    return normalized.isEmpty ? null : normalized;
  }
}
