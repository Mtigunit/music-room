import 'dart:typed_data';

import 'package:equatable/equatable.dart';
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

class ProfileAvatarUploadRequested extends ProfileEvent {
  const ProfileAvatarUploadRequested({
    required this.bytes,
    required this.fileName,
  });

  final Uint8List bytes;
  final String fileName;

  @override
  List<Object?> get props => [bytes, fileName];
}

class ProfileAvatarUploadFailed extends ProfileEvent {
  const ProfileAvatarUploadFailed({
    required this.exception,
    required this.stackTrace,
  });

  final Exception exception;
  final StackTrace stackTrace;

  @override
  List<Object?> get props => [exception, stackTrace];
}

class ProfileSubscriptionUpdateRequested extends ProfileEvent {
  const ProfileSubscriptionUpdateRequested({required this.tier});

  final SubscriptionTier tier;

  @override
  List<Object?> get props => [tier];
}
