import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/services/google_auth_service.dart';
import 'package:music_room/features/profile/domain/entities/profile_entity.dart';
import 'package:music_room/features/settings/domain/repositories/settings_repository.dart';
import 'package:music_room/features/settings/presentation/state/settings_event.dart';
import 'package:music_room/features/settings/presentation/state/settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc({required SettingsRepository settingsRepository})
    : _settingsRepository = settingsRepository,
      super(const SettingsInitial()) {
    on<SettingsRequested>(_onSettingsRequested);
    on<SettingsRefreshRequested>(_onSettingsRefreshRequested);
    on<SettingsSaveSubmitted>(_onSettingsSaveSubmitted);
    on<SettingsPasswordChangeRequested>(_onSettingsPasswordChangeRequested);
    on<SettingsGoogleLinkRequested>(_onSettingsGoogleLinkRequested);
    on<SettingsGoogleUnlinkRequested>(_onSettingsGoogleUnlinkRequested);
  }

  final SettingsRepository _settingsRepository;

  Future<void> _onSettingsRequested(
    SettingsRequested event,
    Emitter<SettingsState> emit,
  ) async {
    emit(const SettingsLoading());

    try {
      final data = await _settingsRepository.loadMySettingsPage();
      emit(SettingsLoaded(data: data));
    } on DioException catch (error) {
      emit(SettingsError(message: _buildErrorMessage(error)));
    } on Object {
      emit(
        const SettingsError(
          message: 'Unable to load settings right now. Please try again.',
        ),
      );
    }
  }

  Future<void> _onSettingsRefreshRequested(
    SettingsRefreshRequested event,
    Emitter<SettingsState> emit,
  ) async {
    add(const SettingsRequested());
  }

  Future<void> _onSettingsSaveSubmitted(
    SettingsSaveSubmitted event,
    Emitter<SettingsState> emit,
  ) async {
    final currentData = _currentLoadedData();
    if (currentData == null) {
      return;
    }

    emit(
      SettingsMutationInProgress(
        data: currentData,
        message: 'Saving settings changes...',
      ),
    );

    try {
      final normalizedUsername = event.request.username?.trim();
      final hasUsernameChange =
          normalizedUsername != null &&
          normalizedUsername.isNotEmpty &&
          normalizedUsername != currentData.profile.username.trim();

      var updated = currentData;

      if (hasUsernameChange) {
        updated = await _settingsRepository.updateMyUsername(
          normalizedUsername,
        );
      }

      if (event.request.toJson().isNotEmpty) {
        updated = await _settingsRepository.updateMySettings(event.request);
      }

      emit(
        SettingsMutationSuccess(
          data: updated,
          message: 'Settings updated successfully.',
        ),
      );
    } on DioException catch (error) {
      emit(
        SettingsMutationFailure(
          data: currentData,
          message: _buildErrorMessage(error),
        ),
      );
    } on Object {
      emit(
        SettingsMutationFailure(
          data: currentData,
          message: 'Unable to update settings right now. Please try again.',
        ),
      );
    }
  }

  Future<void> _onSettingsPasswordChangeRequested(
    SettingsPasswordChangeRequested event,
    Emitter<SettingsState> emit,
  ) async {
    final currentData = _currentLoadedData();
    if (currentData == null) {
      return;
    }

    emit(
      SettingsPasswordChangeInProgress(
        data: currentData,
        message: 'Changing password...',
      ),
    );

    try {
      final updated = await _settingsRepository.changeMyPassword(
        currentPassword: event.currentPassword,
        newPassword: event.newPassword,
      );

      emit(
        SettingsPasswordChangeSuccess(
          data: updated,
          message: 'Password updated successfully.',
        ),
      );
    } on DioException catch (error) {
      emit(
        SettingsPasswordChangeFailure(
          data: currentData,
          message: _buildErrorMessage(
            error,
            fallback: 'Unable to update password right now. Please try again.',
          ),
        ),
      );
    } on Object {
      emit(
        SettingsPasswordChangeFailure(
          data: currentData,
          message: 'Unable to update password right now. Please try again.',
        ),
      );
    }
  }

  Future<void> _onSettingsGoogleLinkRequested(
    SettingsGoogleLinkRequested event,
    Emitter<SettingsState> emit,
  ) async {
    final currentData = _currentLoadedData();
    if (currentData == null || !currentData.profile.isSelf) {
      return;
    }

    emit(
      SettingsGoogleLinkInProgress(
        data: currentData,
        message: 'Linking Google account...',
      ),
    );

    try {
      final updated = await _settingsRepository.linkMyGoogleAccount(
        currentData.profile.id,
      );

      emit(
        SettingsGoogleLinkSuccess(
          data: updated,
          message: 'Google account linked successfully.',
        ),
      );
    } on GoogleAuthException catch (error) {
      emit(
        SettingsGoogleLinkFailure(
          data: currentData,
          message: error.message,
        ),
      );
    } on DioException catch (error) {
      emit(
        SettingsGoogleLinkFailure(
          data: currentData,
          message: _buildErrorMessage(
            error,
            fallback:
                'Unable to link Google account right now. Please try again.',
          ),
        ),
      );
    } on Object {
      emit(
        SettingsGoogleLinkFailure(
          data: currentData,
          message: 'Unable to link Google account right now. Please try again.',
        ),
      );
    }
  }

  Future<void> _onSettingsGoogleUnlinkRequested(
    SettingsGoogleUnlinkRequested event,
    Emitter<SettingsState> emit,
  ) async {
    final currentData = _currentLoadedData();
    if (currentData == null || !currentData.profile.isSelf) {
      return;
    }

    emit(
      SettingsGoogleUnlinkInProgress(
        data: currentData,
        message: 'Removing Google account link...',
      ),
    );

    try {
      final updated = await _settingsRepository.unlinkMyGoogleAccount(
        currentData.profile.id,
      );

      emit(
        SettingsGoogleUnlinkSuccess(
          data: updated,
          message: 'Google account unlinked successfully.',
        ),
      );
    } on DioException catch (error) {
      emit(
        SettingsGoogleUnlinkFailure(
          data: currentData,
          message: _buildGoogleUnlinkErrorMessage(error),
        ),
      );
    } on Object {
      emit(
        SettingsGoogleUnlinkFailure(
          data: currentData,
          message:
              'Unable to unlink Google account right now. Please try again.',
        ),
      );
    }
  }

  ProfilePageData? _currentLoadedData() {
    final currentState = state;
    if (currentState is SettingsLoaded) {
      return currentState.data;
    }
    if (currentState is SettingsMutationInProgress) {
      return currentState.data;
    }
    if (currentState is SettingsMutationSuccess) {
      return currentState.data;
    }
    if (currentState is SettingsMutationFailure) {
      return currentState.data;
    }
    if (currentState is SettingsPasswordChangeInProgress) {
      return currentState.data;
    }
    if (currentState is SettingsPasswordChangeSuccess) {
      return currentState.data;
    }
    if (currentState is SettingsPasswordChangeFailure) {
      return currentState.data;
    }
    if (currentState is SettingsGoogleLinkInProgress) {
      return currentState.data;
    }
    if (currentState is SettingsGoogleLinkSuccess) {
      return currentState.data;
    }
    if (currentState is SettingsGoogleLinkFailure) {
      return currentState.data;
    }
    if (currentState is SettingsGoogleUnlinkInProgress) {
      return currentState.data;
    }
    if (currentState is SettingsGoogleUnlinkSuccess) {
      return currentState.data;
    }
    if (currentState is SettingsGoogleUnlinkFailure) {
      return currentState.data;
    }
    return null;
  }

  String _buildErrorMessage(
    DioException error, {
    String fallback = 'Unable to load settings right now. Please try again.',
  }) {
    final statusCode = error.response?.statusCode;
    final responseData = error.response?.data;

    final extractedMessage = _extractErrorMessage(responseData);
    if (extractedMessage != null) {
      return extractedMessage;
    }

    if (statusCode == 401) {
      return 'Your session expired. Please sign in again.';
    }

    if (statusCode == 404) {
      return 'The requested settings profile was not found.';
    }

    if (statusCode == 403) {
      return 'You do not have access to these settings.';
    }

    return fallback;
  }

  String _buildGoogleUnlinkErrorMessage(DioException error) {
    return _buildErrorMessage(
      error,
      fallback: 'Unable to unlink Google account right now. Please try again.',
    );
  }

  String? _extractErrorMessage(dynamic responseData) {
    if (responseData is String && responseData.trim().isNotEmpty) {
      return responseData.trim();
    }

    if (responseData is Map<String, dynamic>) {
      final message = responseData['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }

      final error = responseData['error'];
      if (error is String && error.trim().isNotEmpty) {
        return error.trim();
      }

      final details = responseData['details'];
      if (details is String && details.trim().isNotEmpty) {
        return details.trim();
      }
    }

    return null;
  }
}
