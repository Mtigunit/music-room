import 'package:equatable/equatable.dart';
import 'package:music_room/features/settings/domain/entities/settings_update_request.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

class SettingsRequested extends SettingsEvent {
  const SettingsRequested();

  @override
  List<Object?> get props => const <Object?>[];
}

class SettingsRefreshRequested extends SettingsEvent {
  const SettingsRefreshRequested();
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
