import 'package:equatable/equatable.dart';
import 'package:music_room/features/profile/domain/entities/profile_entity.dart';

abstract class SettingsState extends Equatable {
  const SettingsState();

  @override
  List<Object?> get props => const <Object?>[];
}

class SettingsInitial extends SettingsState {
  const SettingsInitial();
}

class SettingsLoading extends SettingsState {
  const SettingsLoading();
}

class SettingsLoaded extends SettingsState {
  const SettingsLoaded({required this.data});

  final ProfilePageData data;

  @override
  List<Object?> get props => [data];
}

class SettingsMutationInProgress extends SettingsState {
  const SettingsMutationInProgress({required this.data, required this.message});

  final ProfilePageData data;
  final String message;

  @override
  List<Object?> get props => [data, message];
}

class SettingsMutationSuccess extends SettingsState {
  const SettingsMutationSuccess({required this.data, required this.message});

  final ProfilePageData data;
  final String message;

  @override
  List<Object?> get props => [data, message];
}

class SettingsMutationFailure extends SettingsState {
  const SettingsMutationFailure({required this.data, required this.message});

  final ProfilePageData data;
  final String message;

  @override
  List<Object?> get props => [data, message];
}

class SettingsPasswordChangeInProgress extends SettingsState {
  const SettingsPasswordChangeInProgress({
    required this.data,
    required this.message,
  });

  final ProfilePageData data;
  final String message;

  @override
  List<Object?> get props => [data, message];
}

class SettingsPasswordChangeSuccess extends SettingsState {
  const SettingsPasswordChangeSuccess({
    required this.data,
    required this.message,
  });

  final ProfilePageData data;
  final String message;

  @override
  List<Object?> get props => [data, message];
}

class SettingsPasswordChangeFailure extends SettingsState {
  const SettingsPasswordChangeFailure({
    required this.data,
    required this.message,
  });

  final ProfilePageData data;
  final String message;

  @override
  List<Object?> get props => [data, message];
}

class SettingsGoogleLinkInProgress extends SettingsState {
  const SettingsGoogleLinkInProgress({
    required this.data,
    required this.message,
  });

  final ProfilePageData data;
  final String message;

  @override
  List<Object?> get props => [data, message];
}

class SettingsGoogleLinkSuccess extends SettingsState {
  const SettingsGoogleLinkSuccess({
    required this.data,
    required this.message,
  });

  final ProfilePageData data;
  final String message;

  @override
  List<Object?> get props => [data, message];
}

class SettingsGoogleLinkFailure extends SettingsState {
  const SettingsGoogleLinkFailure({
    required this.data,
    required this.message,
  });

  final ProfilePageData data;
  final String message;

  @override
  List<Object?> get props => [data, message];
}

class SettingsGoogleUnlinkInProgress extends SettingsState {
  const SettingsGoogleUnlinkInProgress({
    required this.data,
    required this.message,
  });

  final ProfilePageData data;
  final String message;

  @override
  List<Object?> get props => [data, message];
}

class SettingsGoogleUnlinkSuccess extends SettingsState {
  const SettingsGoogleUnlinkSuccess({
    required this.data,
    required this.message,
  });

  final ProfilePageData data;
  final String message;

  @override
  List<Object?> get props => [data, message];
}

class SettingsGoogleUnlinkFailure extends SettingsState {
  const SettingsGoogleUnlinkFailure({
    required this.data,
    required this.message,
  });

  final ProfilePageData data;
  final String message;

  @override
  List<Object?> get props => [data, message];
}

class SettingsError extends SettingsState {
  const SettingsError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}

extension SettingsStateX on SettingsState {
  ProfilePageData? get dataOrNull {
    if (this is SettingsLoaded) {
      return (this as SettingsLoaded).data;
    }
    if (this is SettingsMutationInProgress) {
      return (this as SettingsMutationInProgress).data;
    }
    if (this is SettingsMutationSuccess) {
      return (this as SettingsMutationSuccess).data;
    }
    if (this is SettingsMutationFailure) {
      return (this as SettingsMutationFailure).data;
    }
    if (this is SettingsPasswordChangeInProgress) {
      return (this as SettingsPasswordChangeInProgress).data;
    }
    if (this is SettingsPasswordChangeSuccess) {
      return (this as SettingsPasswordChangeSuccess).data;
    }
    if (this is SettingsPasswordChangeFailure) {
      return (this as SettingsPasswordChangeFailure).data;
    }
    if (this is SettingsGoogleLinkInProgress) {
      return (this as SettingsGoogleLinkInProgress).data;
    }
    if (this is SettingsGoogleLinkSuccess) {
      return (this as SettingsGoogleLinkSuccess).data;
    }
    if (this is SettingsGoogleLinkFailure) {
      return (this as SettingsGoogleLinkFailure).data;
    }
    if (this is SettingsGoogleUnlinkInProgress) {
      return (this as SettingsGoogleUnlinkInProgress).data;
    }
    if (this is SettingsGoogleUnlinkSuccess) {
      return (this as SettingsGoogleUnlinkSuccess).data;
    }
    if (this is SettingsGoogleUnlinkFailure) {
      return (this as SettingsGoogleUnlinkFailure).data;
    }

    return null;
  }
}
