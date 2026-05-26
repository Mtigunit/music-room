import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:music_room/features/settings/domain/entities/settings_update_request.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

class SettingsRequested extends SettingsEvent {
  const SettingsRequested({this.userId});

  final String? userId;

  @override
  List<Object?> get props => [userId];
}

class SettingsRefreshRequested extends SettingsEvent {
  const SettingsRefreshRequested({this.userId});

  final String? userId;

  @override
  List<Object?> get props => [userId];
}

class SettingsSaveSubmitted extends SettingsEvent {
  const SettingsSaveSubmitted({required this.request});

  final SettingsUpdateRequest request;

  @override
  List<Object?> get props => [request];
}

class SettingsPasswordChangeRequested extends SettingsEvent {
  const SettingsPasswordChangeRequested({
    required this.currentPassword,
    required this.newPassword,
  });

  final String currentPassword;
  final String newPassword;

  @override
  List<Object?> get props => [currentPassword, newPassword];
}

class SettingsGoogleLinkRequested extends SettingsEvent {
  const SettingsGoogleLinkRequested();
}

class SettingsGoogleUnlinkRequested extends SettingsEvent {
  const SettingsGoogleUnlinkRequested();
}

class SettingsAvatarUploadRequested extends SettingsEvent {
  const SettingsAvatarUploadRequested({
    required this.bytes,
    required this.fileName,
  });

  final Uint8List bytes;
  final String fileName;

  @override
  List<Object?> get props => [bytes, fileName];
}
