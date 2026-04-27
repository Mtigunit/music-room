import 'package:music_room/features/events/data/models/track_model.dart';
import 'package:music_room/features/events/domain/entities/event_tag.dart';

class EventPolicyModel {
  EventPolicyModel({
    required this.policyType,
    required this.config,
  });

  final String policyType;
  final Map<String, dynamic> config;

  Map<String, dynamic> toJson() {
    return {
      'policyType': policyType,
      'config': config,
    };
  }
}

class EventModel {
  EventModel({
    required this.name,
    required this.tags,
    required this.visibility,
    required this.invitingOnly,
    this.description,
    this.locationLat,
    this.locationLng,
    this.playlistIds,
    this.tracks,
    this.policies,
    this.startDate,
  });

  final String name;
  final List<EventTag> tags;
  final String visibility;
  final bool invitingOnly;
  final String? description;
  final double? locationLat;
  final double? locationLng;
  final List<String>? playlistIds;
  final List<TrackModel>? tracks;
  final List<EventPolicyModel>? policies;
  final String? startDate;
}
