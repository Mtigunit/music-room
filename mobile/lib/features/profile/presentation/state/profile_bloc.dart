import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/services/google_auth_service.dart';
import 'package:music_room/features/profile/domain/entities/profile_entity.dart';
import 'package:music_room/features/profile/domain/repositories/profile_repository.dart';
import 'package:music_room/features/profile/presentation/state/profile_event.dart';
import 'package:music_room/features/profile/presentation/state/profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc({required ProfileRepository profileRepository})
    : _profileRepository = profileRepository,
      super(const ProfileInitial()) {
    on<ProfileRequested>(_onProfileRequested);
    on<ProfileRefreshRequested>(_onProfileRefreshRequested);
    on<ProfileFollowRequested>(_onProfileFollowRequested);
    on<ProfileUnfollowRequested>(_onProfileUnfollowRequested);
    on<ProfileEditSubmitted>(_onProfileEditSubmitted);
    on<ProfilePasswordChangeRequested>(_onProfilePasswordChangeRequested);
    on<ProfileGoogleLinkRequested>(_onProfileGoogleLinkRequested);
    on<ProfileGoogleUnlinkRequested>(_onProfileGoogleUnlinkRequested);
    on<ProfileAvatarUploadRequested>(_onProfileAvatarUploadRequested);
  }

  final ProfileRepository _profileRepository;

  Future<void> _onProfileRequested(
    ProfileRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoading());

    try {
      final data = event.userId == null
          ? await _profileRepository.loadMyProfilePage()
          : await _profileRepository.loadUserProfilePage(event.userId!);

      emit(ProfileLoaded(data: data));
    } on DioException catch (error) {
      emit(ProfileError(message: _buildErrorMessage(error)));
    } on Object {
      emit(
        const ProfileError(
          message: 'Unable to load profile right now. Please try again.',
        ),
      );
    }
  }

  Future<void> _onProfileRefreshRequested(
    ProfileRefreshRequested event,
    Emitter<ProfileState> emit,
  ) async {
    add(ProfileRequested(userId: event.userId));
  }

  Future<void> _onProfileFollowRequested(
    ProfileFollowRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final currentData = _currentLoadedData();
    if (currentData == null || currentData.profile.isSelf) {
      return;
    }

    emit(
      ProfileMutationInProgress(
        data: currentData,
        message: _followLoadingMessage(currentData.profile),
      ),
    );

    try {
      final updated = await _profileRepository.followUser(event.userId);
      emit(
        ProfileMutationSuccess(
          data: updated,
          message: _followSuccessMessage(updated.profile),
        ),
      );
    } on DioException catch (error) {
      emit(
        ProfileMutationFailure(
          data: currentData,
          message: _buildErrorMessage(error),
        ),
      );
    } on Object {
      emit(
        ProfileMutationFailure(
          data: currentData,
          message:
              'Unable to update follow status right now. Please try again.',
        ),
      );
    }
  }

  Future<void> _onProfileUnfollowRequested(
    ProfileUnfollowRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final currentData = _currentLoadedData();
    if (currentData == null || currentData.profile.isSelf) {
      return;
    }

    emit(
      ProfileMutationInProgress(
        data: currentData,
        message: _unfollowLoadingMessage(currentData.profile),
      ),
    );

    try {
      final updated = await _profileRepository.unfollowUser(event.userId);
      emit(
        ProfileMutationSuccess(
          data: updated,
          message: _unfollowSuccessMessage(updated.profile),
        ),
      );
    } on DioException catch (error) {
      emit(
        ProfileMutationFailure(
          data: currentData,
          message: _buildErrorMessage(error),
        ),
      );
    } on Object {
      emit(
        ProfileMutationFailure(
          data: currentData,
          message:
              'Unable to update follow status right now. Please try again.',
        ),
      );
    }
  }

  Future<void> _onProfileEditSubmitted(
    ProfileEditSubmitted event,
    Emitter<ProfileState> emit,
  ) async {
    final currentData = _currentLoadedData();
    if (currentData == null) {
      return;
    }

    emit(
      ProfileMutationInProgress(
        data: currentData,
        message: 'Saving profile changes...',
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
        updated = await _profileRepository.updateMyUsername(
          normalizedUsername,
        );
      }

      if (event.request.toJson().isNotEmpty) {
        updated = await _profileRepository.updateMyProfile(event.request);
      }

      emit(
        ProfileMutationSuccess(
          data: updated,
          message: 'Profile updated successfully.',
        ),
      );
    } on DioException catch (error) {
      emit(
        ProfileMutationFailure(
          data: currentData,
          message: _buildErrorMessage(error),
        ),
      );
    } on Object {
      emit(
        ProfileMutationFailure(
          data: currentData,
          message: 'Unable to update profile right now. Please try again.',
        ),
      );
    }
  }

  Future<void> _onProfileAvatarUploadRequested(
    ProfileAvatarUploadRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final currentData = _currentLoadedData();
    if (currentData == null) {
      return;
    }

    emit(
      ProfileMutationInProgress(
        data: currentData,
        message: 'Uploading avatar...',
      ),
    );

    try {
      final updated = await _profileRepository.uploadMyAvatar(
        event.avatar.path,
        event.avatar.name,
      );
      emit(
        ProfileMutationSuccess(
          data: updated,
          message: 'Profile photo updated.',
        ),
      );
    } on DioException catch (error) {
      emit(
        ProfileMutationFailure(
          data: currentData,
          message: _buildErrorMessage(error),
        ),
      );
    } on Object {
      emit(
        ProfileMutationFailure(
          data: currentData,
          message: 'Unable to upload avatar right now. Please try again.',
        ),
      );
    }
  }

  Future<void> _onProfilePasswordChangeRequested(
    ProfilePasswordChangeRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final currentData = _currentLoadedData();
    if (currentData == null) {
      return;
    }

    emit(
      ProfilePasswordChangeInProgress(
        data: currentData,
        message: 'Changing password...',
      ),
    );

    try {
      final updated = await _profileRepository.changeMyPassword(
        currentPassword: event.currentPassword,
        newPassword: event.newPassword,
      );

      emit(
        ProfilePasswordChangeSuccess(
          data: updated,
          message: 'Password updated successfully.',
        ),
      );
    } on DioException catch (error) {
      emit(
        ProfilePasswordChangeFailure(
          data: currentData,
          message: _buildErrorMessage(
            error,
            fallback: 'Unable to update password right now. Please try again.',
          ),
        ),
      );
    } on Object {
      emit(
        ProfilePasswordChangeFailure(
          data: currentData,
          message: 'Unable to update password right now. Please try again.',
        ),
      );
    }
  }

  Future<void> _onProfileGoogleLinkRequested(
    ProfileGoogleLinkRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final currentData = _currentLoadedData();
    if (currentData == null || !currentData.profile.isSelf) {
      return;
    }

    emit(
      ProfileGoogleLinkInProgress(
        data: currentData,
        message: 'Linking Google account...',
      ),
    );

    try {
      final updated = await _profileRepository.linkMyGoogleAccount(
        currentData.profile.id,
      );

      emit(
        ProfileGoogleLinkSuccess(
          data: updated,
          message: 'Google account linked successfully.',
        ),
      );
    } on GoogleAuthException catch (error) {
      emit(
        ProfileGoogleLinkFailure(
          data: currentData,
          message: error.message,
        ),
      );
    } on DioException catch (error) {
      emit(
        ProfileGoogleLinkFailure(
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
        ProfileGoogleLinkFailure(
          data: currentData,
          message: 'Unable to link Google account right now. Please try again.',
        ),
      );
    }
  }

  Future<void> _onProfileGoogleUnlinkRequested(
    ProfileGoogleUnlinkRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final currentData = _currentLoadedData();
    if (currentData == null || !currentData.profile.isSelf) {
      return;
    }

    emit(
      ProfileGoogleUnlinkInProgress(
        data: currentData,
        message: 'Removing Google account link...',
      ),
    );

    try {
      final updated = await _profileRepository.unlinkMyGoogleAccount(
        currentData.profile.id,
      );

      emit(
        ProfileGoogleUnlinkSuccess(
          data: updated,
          message: 'Google account unlinked successfully.',
        ),
      );
    } on DioException catch (error) {
      emit(
        ProfileGoogleUnlinkFailure(
          data: currentData,
          message: _buildGoogleUnlinkErrorMessage(error),
        ),
      );
    } on Object {
      emit(
        ProfileGoogleUnlinkFailure(
          data: currentData,
          message:
              'Unable to unlink Google account right now. Please try again.',
        ),
      );
    }
  }

  ProfilePageData? _currentLoadedData() {
    final currentState = state;
    if (currentState is ProfileLoaded) {
      return currentState.data;
    }
    if (currentState is ProfileMutationInProgress) {
      return currentState.data;
    }
    if (currentState is ProfileMutationSuccess) {
      return currentState.data;
    }
    if (currentState is ProfileMutationFailure) {
      return currentState.data;
    }
    if (currentState is ProfilePasswordChangeInProgress) {
      return currentState.data;
    }
    if (currentState is ProfilePasswordChangeSuccess) {
      return currentState.data;
    }
    if (currentState is ProfilePasswordChangeFailure) {
      return currentState.data;
    }
    if (currentState is ProfileGoogleLinkInProgress) {
      return currentState.data;
    }
    if (currentState is ProfileGoogleLinkSuccess) {
      return currentState.data;
    }
    if (currentState is ProfileGoogleLinkFailure) {
      return currentState.data;
    }
    if (currentState is ProfileGoogleUnlinkInProgress) {
      return currentState.data;
    }
    if (currentState is ProfileGoogleUnlinkSuccess) {
      return currentState.data;
    }
    if (currentState is ProfileGoogleUnlinkFailure) {
      return currentState.data;
    }
    return null;
  }

  String _buildErrorMessage(
    DioException error, {
    String fallback = 'Unable to load profile right now. Please try again.',
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
      return 'The requested profile was not found.';
    }

    if (statusCode == 403) {
      return 'You do not have access to this profile.';
    }

    return fallback;
  }

  String _followLoadingMessage(UserProfileEntity profile) {
    if (profile.isFollowedBy) {
      return 'Following back...';
    }
    return 'Following ${profile.username}...';
  }

  String _followSuccessMessage(UserProfileEntity profile) {
    if (profile.isFollowedBy) {
      return 'Followed back successfully.';
    }
    return 'You are now following ${profile.username}.';
  }

  String _unfollowLoadingMessage(UserProfileEntity profile) {
    return 'Unfollowing ${profile.username}...';
  }

  String _unfollowSuccessMessage(UserProfileEntity profile) {
    return 'You unfollowed ${profile.username}.';
  }

  String _buildGoogleUnlinkErrorMessage(DioException error) {
    final statusCode = error.response?.statusCode;
    final responseData = error.response?.data;

    final extractedMessage = _extractErrorMessage(responseData);
    if (extractedMessage != null) {
      return extractedMessage;
    }

    if (statusCode == 400) {
      return 'Cannot unlink without a password set.';
    }

    if (statusCode == 404) {
      return 'User not found.';
    }

    if (statusCode == 401) {
      return 'Your session expired. Please sign in again.';
    }

    return 'Unable to unlink Google account right now. Please try again.';
  }

  String? _extractErrorMessage(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      final message = responseData['message'];
      final error = responseData['error'];

      final normalizedMessage = _normalizeErrorValue(message);
      if (normalizedMessage != null) {
        return normalizedMessage;
      }

      final normalizedError = _normalizeErrorValue(error);
      if (normalizedError != null) {
        return normalizedError;
      }
    }

    if (responseData is String && responseData.trim().isNotEmpty) {
      return responseData.trim();
    }

    return null;
  }

  String? _normalizeErrorValue(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    if (value is List) {
      final parts = value
          .map(_normalizeErrorValue)
          .whereType<String>()
          .where((part) => part.isNotEmpty)
          .toList();

      if (parts.isEmpty) {
        return null;
      }

      return parts.join(', ');
    }

    return null;
  }
}
