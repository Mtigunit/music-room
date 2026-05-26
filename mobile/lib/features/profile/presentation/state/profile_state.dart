import 'package:equatable/equatable.dart';
import 'package:music_room/features/profile/domain/entities/profile_entity.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => const <Object?>[];
}

class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileLoaded extends ProfileState {
  const ProfileLoaded({required this.data});

  final ProfilePageData data;

  @override
  List<Object?> get props => [data];
}

class ProfileMutationInProgress extends ProfileState {
  const ProfileMutationInProgress({required this.data, required this.message});

  final ProfilePageData data;
  final String message;

  @override
  List<Object?> get props => [data, message];
}

class ProfileMutationSuccess extends ProfileState {
  const ProfileMutationSuccess({required this.data, required this.message});

  final ProfilePageData data;
  final String message;

  @override
  List<Object?> get props => [data, message];
}

class ProfileMutationFailure extends ProfileState {
  const ProfileMutationFailure({required this.data, required this.message});

  final ProfilePageData data;
  final String message;

  @override
  List<Object?> get props => [data, message];
}

class ProfilePasswordChangeInProgress extends ProfileState {
  const ProfilePasswordChangeInProgress({
    required this.data,
    required this.message,
  });

  final ProfilePageData data;
  final String message;

  @override
  List<Object?> get props => [data, message];
}

class ProfilePasswordChangeSuccess extends ProfileState {
  const ProfilePasswordChangeSuccess({
    required this.data,
    required this.message,
  });

  final ProfilePageData data;
  final String message;

  @override
  List<Object?> get props => [data, message];
}

class ProfilePasswordChangeFailure extends ProfileState {
  const ProfilePasswordChangeFailure({
    required this.data,
    required this.message,
  });

  final ProfilePageData data;
  final String message;

  @override
  List<Object?> get props => [data, message];
}

class ProfileGoogleLinkInProgress extends ProfileState {
  const ProfileGoogleLinkInProgress({
    required this.data,
    required this.message,
  });

  final ProfilePageData data;
  final String message;

  @override
  List<Object?> get props => [data, message];
}

class ProfileGoogleLinkSuccess extends ProfileState {
  const ProfileGoogleLinkSuccess({
    required this.data,
    required this.message,
  });

  final ProfilePageData data;
  final String message;

  @override
  List<Object?> get props => [data, message];
}

class ProfileGoogleLinkFailure extends ProfileState {
  const ProfileGoogleLinkFailure({
    required this.data,
    required this.message,
  });

  final ProfilePageData data;
  final String message;

  @override
  List<Object?> get props => [data, message];
}

class ProfileGoogleUnlinkInProgress extends ProfileState {
  const ProfileGoogleUnlinkInProgress({
    required this.data,
    required this.message,
  });

  final ProfilePageData data;
  final String message;

  @override
  List<Object?> get props => [data, message];
}

class ProfileGoogleUnlinkSuccess extends ProfileState {
  const ProfileGoogleUnlinkSuccess({
    required this.data,
    required this.message,
  });

  final ProfilePageData data;
  final String message;

  @override
  List<Object?> get props => [data, message];
}

class ProfileGoogleUnlinkFailure extends ProfileState {
  const ProfileGoogleUnlinkFailure({
    required this.data,
    required this.message,
  });

  final ProfilePageData data;
  final String message;

  @override
  List<Object?> get props => [data, message];
}

class ProfileError extends ProfileState {
  const ProfileError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}

extension ProfileStateX on ProfileState {
  ProfilePageData? get dataOrNull {
    if (this is ProfileLoaded) {
      return (this as ProfileLoaded).data;
    }
    if (this is ProfileMutationInProgress) {
      return (this as ProfileMutationInProgress).data;
    }
    if (this is ProfileMutationSuccess) {
      return (this as ProfileMutationSuccess).data;
    }
    if (this is ProfileMutationFailure) {
      return (this as ProfileMutationFailure).data;
    }
    if (this is ProfilePasswordChangeInProgress) {
      return (this as ProfilePasswordChangeInProgress).data;
    }
    if (this is ProfilePasswordChangeSuccess) {
      return (this as ProfilePasswordChangeSuccess).data;
    }
    if (this is ProfilePasswordChangeFailure) {
      return (this as ProfilePasswordChangeFailure).data;
    }
    if (this is ProfileGoogleLinkInProgress) {
      return (this as ProfileGoogleLinkInProgress).data;
    }
    if (this is ProfileGoogleLinkSuccess) {
      return (this as ProfileGoogleLinkSuccess).data;
    }
    if (this is ProfileGoogleLinkFailure) {
      return (this as ProfileGoogleLinkFailure).data;
    }
    if (this is ProfileGoogleUnlinkInProgress) {
      return (this as ProfileGoogleUnlinkInProgress).data;
    }
    if (this is ProfileGoogleUnlinkSuccess) {
      return (this as ProfileGoogleUnlinkSuccess).data;
    }
    if (this is ProfileGoogleUnlinkFailure) {
      return (this as ProfileGoogleUnlinkFailure).data;
    }

    return null;
  }
}
