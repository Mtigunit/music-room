import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/core/widgets/responsive_layout.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/auth/presentation/layouts/post_registration_profile_layout.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/auth/presentation/state/auth_state.dart';
import 'package:music_room/features/auth/presentation/widgets/auth_screen_header.dart';
import 'package:music_room/features/auth/presentation/widgets/post_registration_profile_actions.dart';
import 'package:music_room/features/auth/presentation/widgets/post_registration_profile_card.dart';
import 'package:music_room/features/auth/presentation/widgets/post_registration_profile_form_sections.dart';
import 'package:music_room/features/auth/presentation/widgets/post_registration_profile_theme_section.dart';
import 'package:music_room/features/settings/domain/entities/settings_update_request.dart';
import 'package:music_room/routes/route_names.dart';

class PostRegistrationProfilePage extends StatefulWidget {
  const PostRegistrationProfilePage({super.key});

  @override
  State<PostRegistrationProfilePage> createState() =>
      _PostRegistrationProfilePageState();
}

class _PostRegistrationProfilePageState
    extends State<PostRegistrationProfilePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final Set<String> _selectedGenres = <String>{};
  String _selectedTheme = 'SYSTEM';
  XFile? _pickedAvatar;
  Uint8List? _pickedAvatarBytes;
  String? _pickedAvatarName;
  String? _avatarUrl;
  bool _isUploadingAvatar = false;
  bool _isSaving = false;
  bool _hasPrefilledUsername = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _prefillUsernameFromAuthState(context.read<AuthBloc>().state);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      builder: (context, screenSize) {
        final layout = ProfileLayout(screenSize);
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final isCompact = layout.isCompact;

        return Scaffold(
          body: SafeArea(
            child: Form(
              key: _formKey,
              child: BlocListener<AuthBloc, AuthState>(
                listener: (context, state) {
                  _prefillUsernameFromAuthState(state);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: layout.horizontalPadding,
                    vertical: layout.verticalPadding,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: layout.contentMaxWidth,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BlocBuilder<AuthBloc, AuthState>(
                            builder: (context, state) {
                              final username = _usernameFromAuthState(state);

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AuthScreenHeader(
                                    title: 'Complete your profile',
                                    subtitle:
                                        'Add a few details to personalize your '
                                        'experience.',
                                    titleFontSize: layout.titleFontSize,
                                    subtitleTopSpacing: layout.welcomeSpacing,
                                    bottomSpacing: 0,
                                  ),
                                  if (username != null) ...[
                                    SizedBox(height: layout.welcomeSpacing),
                                    Text(
                                      'Welcome, @$username',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontSize: layout.welcomeFontSize,
                                            fontWeight: FontWeight.w700,
                                            color: colorScheme.primary,
                                          ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                          SizedBox(height: layout.headerSpacing),
                          if (isCompact)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ProfileCardWidget(
                                  layout: layout,
                                  theme: theme,
                                  avatarUrl: _avatarUrl,
                                  pickedAvatarBytes: _pickedAvatarBytes,
                                  pickedAvatarName: _pickedAvatarName,
                                  isUploadingAvatar: _isUploadingAvatar,
                                  onTap: _isBusy ? null : _pickAvatar,
                                ),
                                SizedBox(height: layout.sectionGap),
                                ProfileFormSections(
                                  layout: layout,
                                  theme: theme,
                                  usernameController: _usernameController,
                                  bioController: _bioController,
                                  locationController: _locationController,
                                  selectedGenres: _selectedGenres,
                                  onGenreTapped: _toggleGenre,
                                  usernameValidator: _validateUsername,
                                ),
                                SizedBox(height: layout.sectionGap),
                                PostRegistrationProfileThemeSection(
                                  layout: layout,
                                  theme: theme,
                                  selectedTheme: _selectedTheme,
                                  onThemeChanged: (value) {
                                    setState(() => _selectedTheme = value);
                                  },
                                ),
                                SizedBox(height: layout.sectionGap),
                                ProfileActionsWidget(
                                  layout: layout,
                                  isSaving: _isSaving,
                                  isBusy: _isBusy,
                                  onSave: _saveProfile,
                                  onSkip: _skip,
                                ),
                              ],
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          ProfileCardWidget(
                                            layout: layout,
                                            theme: theme,
                                            avatarUrl: _avatarUrl,
                                            pickedAvatarBytes:
                                                _pickedAvatarBytes,
                                            pickedAvatarName: _pickedAvatarName,
                                            isUploadingAvatar:
                                                _isUploadingAvatar,
                                            onTap: _isBusy ? null : _pickAvatar,
                                          ),
                                          SizedBox(height: layout.sectionGap),
                                          PostRegistrationProfileThemeSection(
                                            layout: layout,
                                            theme: theme,
                                            selectedTheme: _selectedTheme,
                                            onThemeChanged: (value) {
                                              setState(
                                                () => _selectedTheme = value,
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: layout.columnsGap),
                                    Expanded(
                                      flex: 8,
                                      child: ProfileFormSections(
                                        layout: layout,
                                        theme: theme,
                                        usernameController: _usernameController,
                                        bioController: _bioController,
                                        locationController: _locationController,
                                        selectedGenres: _selectedGenres,
                                        onGenreTapped: _toggleGenre,
                                        usernameValidator: _validateUsername,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: layout.sectionGap),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: SizedBox(
                                    width: layout.actionsMaxWidth,
                                    child: ProfileActionsWidget(
                                      layout: layout,
                                      isSaving: _isSaving,
                                      isBusy: _isBusy,
                                      onSave: _saveProfile,
                                      onSkip: _skip,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAvatar() async {
    if (_isBusy) {
      return;
    }

    final picker = ImagePicker();
    final avatar = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );

    if (!mounted || avatar == null) {
      return;
    }

    final previousAvatarUrl = _avatarUrl;

    setState(() {
      _pickedAvatar = avatar;
      _pickedAvatarBytes = null;
      _pickedAvatarName = avatar.name;
      _isUploadingAvatar = true;
    });

    try {
      final bytes = await avatar.readAsBytes();

      if (!mounted) {
        return;
      }

      setState(() {
        _pickedAvatarBytes = bytes;
      });

      final profileRepository = InjectionContainer().profileRepository;
      final updated = await profileRepository.uploadMyAvatar(
        bytes,
        avatar.name,
      );

      if (!mounted) return;

      setState(() {
        _avatarUrl = updated.profile.avatarUrl ?? previousAvatarUrl;
        _pickedAvatar = null;
        _pickedAvatarBytes = null;
        _pickedAvatarName = null;
        _isUploadingAvatar = false;
      });

      AppSnackbar.showSuccess(context, 'Avatar uploaded.');
    } on DioException catch (error) {
      if (mounted) {
        setState(() {
          _avatarUrl = previousAvatarUrl;
          _pickedAvatar = null;
          _pickedAvatarBytes = null;
          _pickedAvatarName = null;
          _isUploadingAvatar = false;
        });
        AppSnackbar.showError(context, _mapSaveError(error));
      }
    } on Object {
      if (mounted) {
        setState(() {
          _avatarUrl = previousAvatarUrl;
          _pickedAvatar = null;
          _pickedAvatarBytes = null;
          _pickedAvatarName = null;
          _isUploadingAvatar = false;
        });
        AppSnackbar.showError(context, 'Unable to upload avatar. Try again.');
      }
    }
  }

  void _toggleGenre(String genre) {
    setState(() {
      if (_selectedGenres.contains(genre)) {
        _selectedGenres.remove(genre);
      } else if (_selectedGenres.length < 3) {
        _selectedGenres.add(genre);
      }
    });
  }

  Future<void> _saveProfile() async {
    if (_isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final profileRepository = InjectionContainer().profileRepository;
    final settingsRepository = InjectionContainer().settingsRepository;
    final request = SettingsUpdateRequest(
      shortBio: _trimmedValue(_bioController.text),
      location: _trimmedValue(_locationController.text),
      favoriteGenres: _selectedGenres.isEmpty
          ? null
          : _selectedGenres.toList(growable: false),
      uiTheme: _selectedTheme,
    );

    // If username changed, call the dedicated endpoint first
    final authState = context.read<AuthBloc>().state;
    final currentUsername = _usernameFromAuthState(authState);
    final normalizedUsername = _usernameController.text.trim();
    final hasUsernameChange =
        normalizedUsername.isNotEmpty &&
        normalizedUsername != (currentUsername ?? '').trim();

    try {
      if (hasUsernameChange) {
        await settingsRepository.updateMyUsername(normalizedUsername);
      }

      if (request.toJson().isNotEmpty) {
        await settingsRepository.updateMySettings(request);
      }

      if (_pickedAvatarBytes != null) {
        await profileRepository.uploadMyAvatar(
          _pickedAvatarBytes!,
          _pickedAvatarName ?? 'avatar',
        );
      } else if (_pickedAvatar != null) {
        final bytes = await _pickedAvatar!.readAsBytes();
        await profileRepository.uploadMyAvatar(
          bytes,
          _pickedAvatar!.name,
        );
      }

      if (!mounted) {
        return;
      }

      AppSnackbar.showSuccess(context, 'Profile updated successfully.');
      unawaited(
        Navigator.of(context).pushNamedAndRemoveUntil(
          RouteNames.home,
          (_) => false,
        ),
      );
    } on DioException catch (error) {
      if (mounted) {
        AppSnackbar.showError(context, _mapSaveError(error));
      }
    } on Object {
      if (mounted) {
        AppSnackbar.showError(
          context,
          'Unable to save your profile right now. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _skip() {
    if (_isSaving) {
      return;
    }

    unawaited(
      Navigator.of(context).pushNamedAndRemoveUntil(
        RouteNames.home,
        (_) => false,
      ),
    );
  }

  String? _usernameFromAuthState(AuthState state) {
    return switch (state) {
      AuthAuthenticated(:final user) => user.username,
      RegisterSuccess(:final user) => user.username,
      _ => null,
    };
  }

  bool get _isBusy => _isSaving || _isUploadingAvatar;

  void _prefillUsernameFromAuthState(AuthState state) {
    if (_hasPrefilledUsername || _usernameController.text.isNotEmpty) {
      return;
    }

    final username = _usernameFromAuthState(state)?.trim();
    if (username == null || username.isEmpty) {
      return;
    }

    _usernameController.text = username;
    _hasPrefilledUsername = true;
  }

  String? _trimmedValue(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _validateUsername(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Username is required';
    if (v.length < 3) return 'At least 3 characters';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) {
      return 'Only letters, numbers, and underscores';
    }
    return null;
  }

  String _mapSaveError(DioException error) {
    final statusCode = error.response?.statusCode;
    final serverMessage = _extractErrorMessage(error.response?.data);

    return switch (statusCode) {
      400 =>
        serverMessage ??
            'Some of the profile details were invalid. Please review '
                'them and try again.',
      401 => serverMessage ?? 'Your session expired. Please sign in again.',
      409 => serverMessage ?? 'One of your selections is already in use.',
      500 =>
        'The server could not save your profile right now. '
            'Please try again later.',
      _ =>
        serverMessage ??
            'Unable to save your profile right now. Please try again.',
    };
  }

  String? _extractErrorMessage(dynamic responseData) {
    if (responseData is String && responseData.trim().isNotEmpty) {
      return responseData.trim();
    }

    if (responseData is Map<String, dynamic>) {
      final message = responseData['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }

    return null;
  }
}
