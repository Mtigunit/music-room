import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:music_room/features/profile/domain/entities/profile_entity.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

class ProfileRequested extends ProfileEvent {
  const ProfileRequested({this.userId});

  final String? userId;

  @override
  List<Object?> get props => [userId];
}

class ProfileRefreshRequested extends ProfileEvent {
  const ProfileRefreshRequested({this.userId});

  final String? userId;

  @override
  List<Object?> get props => [userId];
}

class ProfileFollowRequested extends ProfileEvent {
  const ProfileFollowRequested({required this.userId});

  final String userId;

  @override
  List<Object?> get props => [userId];
}

class ProfileUnfollowRequested extends ProfileEvent {
  const ProfileUnfollowRequested({required this.userId});

  final String userId;

  @override
  List<Object?> get props => [userId];
}

class ProfileEditSubmitted extends ProfileEvent {
  const ProfileEditSubmitted({required this.request});

  final ProfileUpdateRequest request;

  @override
  List<Object?> get props => [request];
}

class ProfilePasswordChangeRequested extends ProfileEvent {
  const ProfilePasswordChangeRequested({
    required this.currentPassword,
    required this.newPassword,
  });

  final String currentPassword;
  final String newPassword;

  @override
  List<Object?> get props => [currentPassword, newPassword];
}

class ProfileAvatarUploadRequested extends ProfileEvent {
  const ProfileAvatarUploadRequested({required this.avatar});

  final XFile avatar;

  @override
  List<Object?> get props => [avatar.path, avatar.name];
}
