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
