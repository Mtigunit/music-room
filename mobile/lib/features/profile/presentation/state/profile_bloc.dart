import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
      final updated = await _profileRepository.updateMyProfile(event.request);
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
    return null;
  }

  String _buildErrorMessage(DioException error) {
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

    return 'Unable to load profile right now. Please try again.';
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
