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
}
