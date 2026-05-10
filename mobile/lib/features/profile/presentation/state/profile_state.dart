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

class ProfileError extends ProfileState {
  const ProfileError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
