import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:music_room/core/config/app_config.dart';
import 'package:music_room/core/network/api_client.dart';
import 'package:music_room/features/events/data/models/event_model.dart';
import 'package:music_room/features/events/domain/entities/my_event_item_model.dart';

// ---------------------------------------------------------------------------
// Interface
// ---------------------------------------------------------------------------

abstract class IEventRemoteDataSource {
  Future<String> createEvent(EventModel event, XFile? coverImage);
  Future<void> updateEvent(String id, EventModel event, XFile? coverImage);

  /// Returns events the authenticated user has been invited to.
  Future<List<MyEventItemModel>> fetchInvitedEvents({
    int page = 1,
    int limit = 20,
  });

  /// Returns events the authenticated user is hosting.
  Future<List<MyEventItemModel>> fetchHostedEvents({
    int page = 1,
    int limit = 20,
  });

  /// Returns public events for discovery.
  Future<List<MyEventItemModel>> fetchPublicEvents({
    int page = 1,
    int limit = 20,
  });
}

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

class EventRemoteDataSource implements IEventRemoteDataSource {
  EventRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  // ── Create Event ──────────────────────────────────────────────────────────

  @override
  Future<String> createEvent(EventModel event, XFile? coverImage) async {
    try {
      final mapData = await _buildFormDataMap(event, coverImage);
      if (kDebugMode) {
        debugPrint('--- [CREATE EVENT] SENDING DATA ---');
        debugPrint(mapData.toString());
      }

      final formData = FormData.fromMap(mapData);

      final response = await _apiClient.post<Map<String, dynamic>>(
        AppConfig.eventsEndpoint,
        data: formData,
      );

      return _parseCreateEventResponse(response);
    } on DioException catch (e) {
      debugPrint('--- [CREATE EVENT] DIO ERROR THROWN ---');
      debugPrint(e.toString());
      if (e.response != null) {
        debugPrint('Response Data: ${e.response?.data}');
      }
      rethrow;
    } on Object catch (e) {
      debugPrint('--- [CREATE EVENT] UNKNOWN ERROR THROWN ---');
      debugPrint(e.toString());
      throw DioException(
        requestOptions: RequestOptions(path: AppConfig.eventsEndpoint),
        error: e,
      );
    }
  }

  // ── Update Event ──────────────────────────────────────────────────────────

  @override
  Future<void> updateEvent(
    String id,
    EventModel event,
    XFile? coverImage,
  ) async {
    try {
      final mapData = await _buildFormDataMap(event, coverImage);
      if (kDebugMode) {
        debugPrint('--- [UPDATE EVENT] SENDING DATA ---');
        debugPrint(mapData.toString());
      }

      final formData = FormData.fromMap(mapData);

      await _apiClient.patch<Map<String, dynamic>>(
        '${AppConfig.eventsEndpoint}/$id',
        data: formData,
      );
    } on DioException catch (e) {
      debugPrint('--- [UPDATE EVENT] DIO ERROR THROWN ---');
      debugPrint(e.toString());
      if (e.response != null) {
        debugPrint('Response Data: ${e.response?.data}');
      }
      rethrow;
    } on Object catch (e) {
      debugPrint('--- [UPDATE EVENT] UNKNOWN ERROR THROWN ---');
      debugPrint(e.toString());
      throw DioException(
        requestOptions: RequestOptions(path: '${AppConfig.eventsEndpoint}/$id'),
        error: e,
      );
    }
  }

  // ── Fetch Invited Events ──────────────────────────────────────────────────

  @override
  Future<List<MyEventItemModel>> fetchInvitedEvents({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiClient.get<dynamic>(
        AppConfig.eventsInvitedEndpoint,
        queryParameters: {'page': page, 'limit': limit},
      );

      return _parseEventListResponse(response);
    } on DioException {
      rethrow;
    } on Object catch (e) {
      throw DioException(
        requestOptions: RequestOptions(path: AppConfig.eventsInvitedEndpoint),
        error: e,
      );
    }
  }

  // ── Fetch Hosted Events ───────────────────────────────────────────────────

  @override
  Future<List<MyEventItemModel>> fetchHostedEvents({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiClient.get<dynamic>(
        AppConfig.eventsHostingEndpoint,
        queryParameters: {'page': page, 'limit': limit},
      );

      return _parseEventListResponse(response);
    } on DioException {
      rethrow;
    } on Object catch (e) {
      throw DioException(
        requestOptions: RequestOptions(path: AppConfig.eventsHostingEndpoint),
        error: e,
      );
    }
  }

  // ── Fetch Public Events ──────────────────────────────────────────────────

  @override
  Future<List<MyEventItemModel>> fetchPublicEvents({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiClient.get<dynamic>(
        AppConfig.eventsEndpoint,
        queryParameters: {'page': page, 'limit': limit},
      );

      return _parseEventListResponse(response);
    } on DioException {
      rethrow;
    } on Object catch (e) {
      throw DioException(
        requestOptions: RequestOptions(path: AppConfig.eventsEndpoint),
        error: e,
      );
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Parses a paginated list response.
  ///
  /// Supports two common backend shapes:
  ///  - `{ "data": [ ... ] }` (paginated wrapper)
  ///  - `[ ... ]`             (plain array)
  List<MyEventItemModel> _parseEventListResponse(
    Response<dynamic> response,
  ) {
    final statusCode = response.statusCode;
    final body = response.data;

    final isSuccess = statusCode == 200 || statusCode == 201;
    if (!isSuccess || body == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }

    // Accept both `{ data: [...] }` and bare `[...]` responses.
    final List<dynamic> items;
    if (body is List) {
      items = body;
    } else if (body is Map<String, dynamic>) {
      if (body['data'] is List) {
        items = body['data'] as List<dynamic>;
      } else if (body['items'] is List) {
        items = body['items'] as List<dynamic>;
      } else {
        items = const [];
      }
    } else {
      items = const [];
    }

    return items
        .whereType<Map<String, dynamic>>()
        .map(MyEventItemModel.fromJson)
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _buildFormDataMap(
    EventModel event,
    XFile? coverImage,
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
        tracks
            .map(
              (track) => {'providerTrackId': track.providerTrackId},
            )
            .toList(growable: false),
      );
    }

    final policies = event.policies;
    if (policies != null && policies.isNotEmpty) {
      formData['policies'] = jsonEncode(
        policies.map((policy) => policy.toJson()).toList(growable: false),
      );
    }

    if (event.startDate != null) {
      formData['startDate'] = event.startDate;
    }

    if (coverImage != null) {
      if (kIsWeb) {
        formData['coverImage'] = MultipartFile.fromBytes(
          await coverImage.readAsBytes(),
          filename: coverImage.name,
        );
      } else {
        formData['coverImage'] = await MultipartFile.fromFile(
          coverImage.path,
          filename: coverImage.name,
        );
      }
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
