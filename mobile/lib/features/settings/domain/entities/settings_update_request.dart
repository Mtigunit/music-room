import 'package:equatable/equatable.dart';

class SettingsUpdateRequest extends Equatable {
  const SettingsUpdateRequest({
    this.username,
    this.shortBio,
    this.location,
    this.dateOfBirth,
    this.physicalAddress,
    this.favoriteGenres,
    this.autoAcceptInvites,
    this.uiTheme,
  });

  final String? username;
  final String? shortBio;
  final String? location;
  final String? dateOfBirth;
  final String? physicalAddress;
  final List<String>? favoriteGenres;
  final bool? autoAcceptInvites;
  final String? uiTheme;

  bool hasChanges({String? currentUsername}) {
    final normalizedUsername = username?.trim();
    final hasUsernameChange =
        normalizedUsername != null &&
        normalizedUsername.isNotEmpty &&
        normalizedUsername != currentUsername?.trim();

    final hasProfileFieldChanges =
        (shortBio?.trim().isNotEmpty ?? false) ||
        (location?.trim().isNotEmpty ?? false) ||
        (dateOfBirth?.trim().isNotEmpty ?? false) ||
        (physicalAddress?.trim().isNotEmpty ?? false) ||
        (favoriteGenres?.isNotEmpty ?? false) ||
        autoAcceptInvites != null ||
        (uiTheme?.trim().isNotEmpty ?? false);

    return hasUsernameChange || hasProfileFieldChanges;
  }

  Map<String, dynamic> toJson() {
    final publicInfo = <String, dynamic>{};
    final friendInfo = <String, dynamic>{};
    final privateInfo = <String, dynamic>{};
    final preferences = <String, dynamic>{};

    final trimmedBio = shortBio?.trim();
    if (trimmedBio != null && trimmedBio.isNotEmpty) {
      publicInfo['shortBio'] = trimmedBio;
    }

    final trimmedLocation = location?.trim();
    if (trimmedLocation != null && trimmedLocation.isNotEmpty) {
      friendInfo['location'] = trimmedLocation;
    }

    final trimmedDateOfBirth = dateOfBirth?.trim();
    if (trimmedDateOfBirth != null && trimmedDateOfBirth.isNotEmpty) {
      privateInfo['dateOfBirth'] = trimmedDateOfBirth;
    }

    final trimmedPhysicalAddress = physicalAddress?.trim();
    if (trimmedPhysicalAddress != null && trimmedPhysicalAddress.isNotEmpty) {
      privateInfo['physicalAddress'] = trimmedPhysicalAddress;
    }

    if (favoriteGenres != null && favoriteGenres!.isNotEmpty) {
      preferences['favoriteGenres'] = favoriteGenres;
    }

    if (autoAcceptInvites != null) {
      preferences['autoAcceptInvites'] = autoAcceptInvites;
    }

    final trimmedUiTheme = uiTheme?.trim();
    if (trimmedUiTheme != null && trimmedUiTheme.isNotEmpty) {
      preferences['uiTheme'] = trimmedUiTheme;
    }

    final payload = <String, dynamic>{};
    if (publicInfo.isNotEmpty) {
      payload['publicInfo'] = publicInfo;
    }
    if (friendInfo.isNotEmpty) {
      payload['friendInfo'] = friendInfo;
    }
    if (privateInfo.isNotEmpty) {
      payload['privateInfo'] = privateInfo;
    }
    if (preferences.isNotEmpty) {
      payload['preferences'] = preferences;
    }

    return payload;
  }

  @override
  List<Object?> get props => [
    username,
    shortBio,
    location,
    dateOfBirth,
    physicalAddress,
    favoriteGenres,
    autoAcceptInvites,
    uiTheme,
  ];
}
