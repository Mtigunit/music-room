import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/utils/logger.dart';
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
    on<ProfileAvatarUploadRequested>(_onProfileAvatarUploadRequested);
    on<ProfileAvatarUploadFailed>(_onProfileAvatarUploadFailed);
    on<ProfileSubscriptionUpdateRequested>(
      _onProfileSubscriptionUpdateRequested,
    );
  }

  final ProfileRepository _profileRepository;
  final Logger _logger = Logger();

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
        event.bytes,
        event.fileName,
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

  Future<void> _onProfileAvatarUploadFailed(
    ProfileAvatarUploadFailed event,
    Emitter<ProfileState> emit,
  ) async {
    final currentData = _currentLoadedData();
    const message = 'Unable to read selected image. Please try again.';

    _logger.log(
      '[ProfileBloc] Avatar image read failed: ${event.exception}\n'
      '${event.stackTrace}',
    );

    if (currentData == null) {
      emit(const ProfileError(message: message));
      return;
    }

    emit(
      ProfileMutationFailure(
        data: currentData,
        message: message,
      ),
    );
  }

  Future<void> _onProfileSubscriptionUpdateRequested(
    ProfileSubscriptionUpdateRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final currentData = _currentLoadedData();
    if (currentData == null) return;

    final tierLabel = event.tier == SubscriptionTier.premium
        ? 'Premium'
        : 'Basic';

    emit(
      ProfileMutationInProgress(
        data: currentData,
        message: 'Updating to $tierLabel plan...',
      ),
    );

    try {
      final updated = await _profileRepository.updateSubscription(
        event.tier.apiValue,
      );
      emit(
        ProfileMutationSuccess(
          data: updated,
          message: 'Switched to $tierLabel plan.',
        ),
      );
    } on DioException catch (error) {
      emit(
        ProfileMutationFailure(
          data: currentData,
          message: _buildErrorMessage(
            error,
            fallback: 'Unable to update subscription. Please try again.',
          ),
        ),
      );
    } on Object {
      emit(
        ProfileMutationFailure(
          data: currentData,
          message: 'Unable to update subscription. Please try again.',
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
    return 'Following @${profile.username}...';
  }

  String _followSuccessMessage(UserProfileEntity profile) {
    return 'Now following @${profile.username}.';
  }

  String _unfollowLoadingMessage(UserProfileEntity profile) {
    return 'Unfollowing @${profile.username}...';
  }

  String _unfollowSuccessMessage(UserProfileEntity profile) {
    return 'Unfollowed @${profile.username}.';
  }

  String? _extractErrorMessage(dynamic error) {
    if (error is String && error.trim().isNotEmpty) {
      return error.trim();
    }

    if (error is Map<String, dynamic>) {
      final message = error['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }

      final details = error['details'];
      if (details is String && details.trim().isNotEmpty) {
        return details.trim();
      }

      final errorText = error['error'];
      if (errorText is String && errorText.trim().isNotEmpty) {
        return errorText.trim();
      }
    }

    return null;
  }
}
