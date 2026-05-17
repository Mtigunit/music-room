import 'package:dio/dio.dart';
import 'package:music_room/core/config/app_config.dart';
import 'package:music_room/core/network/api_client.dart';
import 'package:music_room/features/music_vote/data/models/event_delegated_user_model.dart';
import 'package:music_room/features/music_vote/data/models/event_detail_model.dart';
import 'package:music_room/features/music_vote/data/models/event_invited_user_model.dart';
import 'package:music_room/features/music_vote/data/models/event_track_model.dart';

/// Contract for the Music Vote (Live Room) remote data source.
abstract class IMusicVoteRemoteDataSource {
  /// GET /events/{eventId} — fetch event details.
  Future<EventDetailModel> getEventDetails(String eventId);

  /// GET /events/{eventId}/tracks?page=&limit= — fetch queued tracks.
  Future<List<EventTrackModel>> getEventTracks(
    String eventId, {
    int page,
    int limit,
  });

  /// POST /events/{eventId}/tracks — append a track to the queue.
  Future<EventTrackModel> addTrackToEvent(
    String eventId,
    String providerTrackId,
  );

  /// DELETE /events/{eventId}/tracks/{providerTrackId} — remove a track.
  Future<void> removeTrackFromEvent(String eventId, String providerTrackId);

  /// POST /events/{eventId}/invites — invite a user to the event.
  Future<void> inviteUserToEvent(String eventId, String userId);

  /// GET /events/{eventId}/invited?page=&limit= — list users invited to
  /// the event. Returns the parsed paginated payload.
  Future<EventInvitedUsersPage> getInvitedUsers(
    String eventId, {
    int page,
    int limit,
  });

  /// POST /events/{eventId}/delegations — grant playback delegation to a
  /// previously invited user. Returns the created `delegationId` so the
  /// caller can cross-reference incoming socket events.
  Future<String> createDelegation(String eventId, String delegateeId);

  /// GET /events/{eventId}/delegations — list active delegated users for an event.
  Future<List<EventDelegatedUserModel>> getDelegatedUsers(String eventId);

  /// DELETE /events/{eventId}/delegations/{userId} — revoke playback delegation.
  Future<void> removeDelegation(String eventId, String userId);
}

/// Page wrapper for [IMusicVoteRemoteDataSource.getInvitedUsers].
class EventInvitedUsersPage {
  const EventInvitedUsersPage({
    required this.users,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  final List<EventInvitedUserModel> users;
  final int total;
  final int page;
  final int limit;
  final int totalPages;
}

class MusicVoteRemoteDataSource implements IMusicVoteRemoteDataSource {
  MusicVoteRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<EventDetailModel> getEventDetails(String eventId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '${AppConfig.eventsEndpoint}/$eventId',
      );

      if (response.statusCode == 200 && response.data != null) {
        return EventDetailModel.fromJson(response.data!);
      }

      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    } on DioException {
      rethrow;
    } on Object catch (e) {
      throw DioException(
        requestOptions: RequestOptions(
          path: '${AppConfig.eventsEndpoint}/$eventId',
        ),
        error: e,
      );
    }
  }

  @override
  Future<List<EventTrackModel>> getEventTracks(
    String eventId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '${AppConfig.eventsEndpoint}/$eventId/tracks',
        queryParameters: {'page': page, 'limit': limit},
      );

      if (response.statusCode == 200 && response.data != null) {
        final rawData = response.data!['data'];
        if (rawData is List) {
          return rawData
              .map(
                (json) =>
                    EventTrackModel.fromJson(json as Map<String, dynamic>),
              )
              .toList();
        }
      }

      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    } on DioException {
      rethrow;
    } on Object catch (e) {
      throw DioException(
        requestOptions: RequestOptions(
          path: '${AppConfig.eventsEndpoint}/$eventId/tracks',
        ),
        error: e,
      );
    }
  }

  @override
  Future<EventTrackModel> addTrackToEvent(
    String eventId,
    String providerTrackId,
  ) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '${AppConfig.eventsEndpoint}/$eventId/tracks',
        data: {'providerTrackId': providerTrackId},
      );

      final isSuccess =
          response.statusCode == 200 || response.statusCode == 201;
      if (isSuccess && response.data != null) {
        return EventTrackModel.fromJson(response.data!);
      }

      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    } on DioException {
      rethrow;
    } on Object catch (e) {
      throw DioException(
        requestOptions: RequestOptions(
          path: '${AppConfig.eventsEndpoint}/$eventId/tracks',
        ),
        error: e,
      );
    }
  }

  @override
  Future<void> removeTrackFromEvent(
    String eventId,
    String providerTrackId,
  ) async {
    try {
      final response = await _apiClient.delete<dynamic>(
        '${AppConfig.eventsEndpoint}/$eventId/tracks/$providerTrackId',
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      }

      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    } on DioException {
      rethrow;
    } on Object catch (e) {
      throw DioException(
        requestOptions: RequestOptions(
          path: '${AppConfig.eventsEndpoint}/$eventId/tracks/$providerTrackId',
        ),
        error: e,
      );
    }
  }

  @override
  Future<EventInvitedUsersPage> getInvitedUsers(
    String eventId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '${AppConfig.eventsEndpoint}/$eventId/invited',
        queryParameters: <String, dynamic>{'page': page, 'limit': limit},
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        final rawList = data['data'];
        final rawPagination = data['pagination'] is Map<String, dynamic>
            ? data['pagination'] as Map<String, dynamic>
            : const <String, dynamic>{};

        final users = rawList is List
            ? rawList
                  .whereType<Map<String, dynamic>>()
                  .map(EventInvitedUserModel.fromJson)
                  .toList(growable: false)
            : const <EventInvitedUserModel>[];

        return EventInvitedUsersPage(
          users: users,
          total: (rawPagination['total'] as num?)?.toInt() ?? users.length,
          page: (rawPagination['page'] as num?)?.toInt() ?? page,
          limit: (rawPagination['limit'] as num?)?.toInt() ?? limit,
          totalPages: (rawPagination['totalPages'] as num?)?.toInt() ?? 1,
        );
      }

      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    } on DioException {
      rethrow;
    } on Object catch (e) {
      throw DioException(
        requestOptions: RequestOptions(
          path: '${AppConfig.eventsEndpoint}/$eventId/invited',
        ),
        error: e,
      );
    }
  }

  @override
  Future<String> createDelegation(String eventId, String delegateeId) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '${AppConfig.eventsEndpoint}/$eventId/delegations',
        data: <String, dynamic>{'delegateeId': delegateeId},
      );

      final isSuccess =
          response.statusCode == 200 || response.statusCode == 201;
      if (isSuccess && response.data != null) {
        final data = response.data!;
        final delegationId = data['delegationId'];
        if (delegationId is String && delegationId.isNotEmpty) {
          return delegationId;
        }
        // Backend always returns a delegationId; treat its absence as a bad
        // response so the caller can surface a clear error.
      }

      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    } on DioException {
      rethrow;
    } on Object catch (e) {
      throw DioException(
        requestOptions: RequestOptions(
          path: '${AppConfig.eventsEndpoint}/$eventId/delegations',
        ),
        error: e,
      );
    }
  }

  @override
  Future<void> inviteUserToEvent(String eventId, String userId) async {
    try {
      final response = await _apiClient.post<dynamic>(
        '${AppConfig.eventsEndpoint}/$eventId/invites',
        data: {'userId': userId},
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        return;
      }

      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    } on DioException {
      rethrow;
    } on Object catch (e) {
      throw DioException(
        requestOptions: RequestOptions(
          path: '${AppConfig.eventsEndpoint}/$eventId/invites',
        ),
        error: e,
      );
    }
  }

  @override
  Future<List<EventDelegatedUserModel>> getDelegatedUsers(
    String eventId,
  ) async {
    try {
      final response = await _apiClient.get<dynamic>(
        '${AppConfig.eventsEndpoint}/$eventId/delegations',
      );

      if (response.statusCode == 200 && response.data != null) {
        final rawData = response.data;
        if (rawData is List) {
          return rawData
              .whereType<Map<String, dynamic>>()
              .map(EventDelegatedUserModel.fromJson)
              .toList();
        }
        return const <EventDelegatedUserModel>[];
      }

      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    } on DioException {
      rethrow;
    } on Object catch (e) {
      throw DioException(
        requestOptions: RequestOptions(
          path: '${AppConfig.eventsEndpoint}/$eventId/delegations',
        ),
        error: e,
      );
    }
  }

  @override
  Future<void> removeDelegation(String eventId, String userId) async {
    try {
      final response = await _apiClient.delete<dynamic>(
        '${AppConfig.eventsEndpoint}/$eventId/delegations/$userId',
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      }

      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    } on DioException {
      rethrow;
    } on Object catch (e) {
      throw DioException(
        requestOptions: RequestOptions(
          path: '${AppConfig.eventsEndpoint}/$eventId/delegations/$userId',
        ),
        error: e,
      );
    }
  }
}
