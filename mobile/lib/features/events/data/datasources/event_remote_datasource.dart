import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:music_room/core/config/app_config.dart';
import 'package:music_room/core/network/api_client.dart';
import 'package:music_room/features/events/data/models/event_model.dart';

// ignore: one_member_abstracts, reason: Interfaces for Repositories/Datasources often start with one method
abstract class IEventRemoteDataSource {
  Future<String> createEvent(EventModel event, File? coverImage);
}

class EventRemoteDataSource implements IEventRemoteDataSource {
  EventRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<String> createEvent(EventModel event, File? coverImage) async {
    try {
      final formData = FormData.fromMap(
        await _buildFormDataMap(event, coverImage),
      );

      final response = await _apiClient.post<Map<String, dynamic>>(
        AppConfig.eventsEndpoint,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      return _parseCreateEventResponse(response);
    } on DioException {
      rethrow;
    } on Object catch (e) {
      throw DioException(
        requestOptions: RequestOptions(path: AppConfig.eventsEndpoint),
        error: e,
      );
    }
  }

  Future<Map<String, dynamic>> _buildFormDataMap(
    EventModel event,
    File? coverImage,
  ) async {
    final formData = <String, dynamic>{
      'name': event.name,
      'tags': jsonEncode(
        event.tags.map((tag) => tag.backendValue).toList(growable: false),
      ),
      'visibility': event.visibility,
      'invitingOnly': event.invitingOnly.toString(),
    };

    final description = event.description?.trim();
    if (description != null && description.isNotEmpty) {
      formData['description'] = description;
    }

    if (event.locationLat != null) {
      formData['locationLat'] = event.locationLat!.toString();
    }

    if (event.locationLng != null) {
      formData['locationLng'] = event.locationLng!.toString();
    }

    final playlistIds = event.playlistIds;
    if (playlistIds != null && playlistIds.isNotEmpty) {
      formData['playlistIds'] = jsonEncode(playlistIds);
    }

    final tracks = event.tracks;
    if (tracks != null && tracks.isNotEmpty) {
      formData['tracks'] = jsonEncode(
        tracks.map((track) => track.toJson()).toList(growable: false),
      );
    }

    final policies = event.policies;
    if (policies != null && policies.isNotEmpty) {
      formData['policies'] = jsonEncode(
        policies.map((policy) => policy.toJson()).toList(growable: false),
      );
    }

    if (coverImage != null) {
      formData['coverImage'] = await MultipartFile.fromFile(
        coverImage.path,
        filename: coverImage.uri.pathSegments.last,
      );
    }

    return formData;
  }

  String _parseCreateEventResponse(Response<Map<String, dynamic>> response) {
    final statusCode = response.statusCode;
    final data = response.data;

    final isSuccess = statusCode == 200 || statusCode == 201;
    if (isSuccess && data != null) {
      final eventId = data['id'];
      if (eventId is String && eventId.isNotEmpty) {
        return eventId;
      }
    }

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
    );
  }
}
