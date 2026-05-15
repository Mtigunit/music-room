import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:music_room/core/widgets/app_button.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/core/widgets/form_input_decoration.dart';
import 'package:music_room/core/widgets/form_section_label.dart';
import 'package:music_room/core/widgets/genre_selection_grid.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/auth/presentation/state/auth_state.dart';
import 'package:music_room/features/auth/presentation/widgets/auth_page_layout.dart';
import 'package:music_room/features/auth/presentation/widgets/auth_screen_header.dart';
import 'package:music_room/features/events/presentation/widgets/selection_card.dart';
import 'package:music_room/features/playlist/domain/types/playlist_tags.dart';
import 'package:music_room/features/profile/domain/entities/profile_entity.dart';
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: AuthPageLayout(
          showBrandPanel: false,
          child: Form(
            key: _formKey,
            child: BlocListener<AuthBloc, AuthState>(
              listener: (context, state) {
                _prefillUsernameFromAuthState(state);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      final username = _usernameFromAuthState(state);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AuthScreenHeader(
                            title: 'Complete your profile',
                            subtitle:
                                'Add a few details to personalize '
                                'your experience.',
                          ),
                          if (username != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Welcome, @$username',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildProfileCard(context),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    decoration: FormInputDecoration.build(
                      theme,
                      labelText: null,
                      hintText: 'Username',
                    ),
                    validator: _validateUsername,
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bioController,
                    maxLines: 4,
                    maxLength: 150,
                    decoration: FormInputDecoration.build(
                      theme,
                      labelText: null,
                      hintText: 'Tell people what you are into',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _locationController,
                    decoration: FormInputDecoration.build(
                      theme,
                      labelText: null,
                      hintText: 'City or region',
                    ),
                  ),
                  const SizedBox(height: 20),
                  const FormSectionLabel(text: 'Favorite genres'),
                  const SizedBox(height: 10),
                  GenreSelectionGrid(
                    genres: PlaylistTag.all
                        .map((tag) => tag.displayLabel)
                        .toList(growable: false),
                    selectedGenres: _selectedGenres
                        .map(
                          (value) => PlaylistTag.fromValue(value)?.displayLabel,
                        )
                        .whereType<String>()
                        .toList(growable: false),
                    maxSelection: 4,
                    onGenreTapped: _toggleGenre,
                  ),
                  const SizedBox(height: 20),
                  const FormSectionLabel(text: 'Theme preference'),
                  const SizedBox(height: 10),
                  _ThemeOptionCard(
                    title: 'System',
                    subtitle: 'Match the device appearance.',
                    icon: Icons.brightness_auto_rounded,
                    isSelected: _selectedTheme == 'SYSTEM',
                    onTap: () => setState(() => _selectedTheme = 'SYSTEM'),
                  ),
                  const SizedBox(height: 10),
                  _ThemeOptionCard(
                    title: 'Light',
                    subtitle: 'Use the lighter visual mode.',
                    icon: Icons.light_mode_rounded,
                    isSelected: _selectedTheme == 'LIGHT',
                    onTap: () => setState(() => _selectedTheme = 'LIGHT'),
                  ),
                  const SizedBox(height: 10),
                  _ThemeOptionCard(
                    title: 'Dark',
                    subtitle: 'Use the darker visual mode.',
                    icon: Icons.dark_mode_rounded,
                    isSelected: _selectedTheme == 'DARK',
                    onTap: () => setState(() => _selectedTheme = 'DARK'),
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 520;

                      if (isCompact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppButton(
                              onPressed: _isBusy ? null : _saveProfile,
                              isLoading: _isSaving,
                              label: 'Save and continue',
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            const SizedBox(height: 12),
                            AppButton(
                              onPressed: _isBusy ? null : _skip,
                              variant: AppButtonVariant.text,
                              label: 'Skip for now',
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              onPressed: _isBusy ? null : _saveProfile,
                              isLoading: _isSaving,
                              label: 'Save and continue',
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppButton(
                              onPressed: _isBusy ? null : _skip,
                              variant: AppButtonVariant.outlined,
                              label: 'Skip for now',
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: _isBusy ? null : _pickAvatar,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Builder(
              builder: (context) {
                final avatarImage = _avatarUrl != null
                    ? NetworkImage(_avatarUrl!) as ImageProvider<Object>?
                    : (_pickedAvatar != null
                          ? (kIsWeb
                                    ? NetworkImage(_pickedAvatar!.path)
                                    : FileImage(File(_pickedAvatar!.path)))
                                as ImageProvider<Object>?
                          : null);

                return CircleAvatar(
                  radius: 28,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                  backgroundImage: avatarImage,
                  child: avatarImage == null
                      ? Icon(
                          Icons.add_a_photo_rounded,
                          color: colorScheme.primary,
                        )
                      : (_isUploadingAvatar
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colorScheme.primary,
                                  ),
                                ),
                              )
                            : null),
                );
              },
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile photo',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _avatarUrl != null
                        ? 'Photo uploaded'
                        : (_pickedAvatar == null
                              ? 'Tap to add a photo later from your profile.'
                              : 'Photo selected: ${_pickedAvatar!.name}'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
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

    setState(() {
      _pickedAvatar = avatar;
      _isUploadingAvatar = true;
      _avatarUrl = null;
    });

    try {
      final bytes = await avatar.readAsBytes();
      final avatarName = avatar.name;
      final profileRepository = InjectionContainer().profileRepository;
      final updated = await profileRepository.uploadMyAvatar(
        bytes,
        avatarName,
      );

      if (!mounted) return;

      setState(() {
        _avatarUrl = updated.profile.avatarUrl;
        _pickedAvatar = null;
        _isUploadingAvatar = false;
      });

      AppSnackbar.showSuccess(context, 'Avatar uploaded.');
    } on DioException catch (error) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        AppSnackbar.showError(context, _mapSaveError(error));
      }
    } on Object {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        AppSnackbar.showError(context, 'Unable to upload avatar. Try again.');
      }
    }
  }

  void _toggleGenre(String genre) {
    setState(() {
      final tag = _playlistTagFromDisplayLabel(genre);

      if (_selectedGenres.contains(tag.value)) {
        _selectedGenres.remove(tag.value);
      } else if (_selectedGenres.length < 4) {
        _selectedGenres.add(tag.value);
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
    final request = ProfileUpdateRequest(
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
        await profileRepository.updateMyUsername(normalizedUsername);
      }

      if (request.toJson().isNotEmpty) {
        await profileRepository.updateMyProfile(request);
      }

      if (_pickedAvatar != null) {
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

  PlaylistTag _playlistTagFromDisplayLabel(String displayLabel) {
    return PlaylistTag.all.firstWhere(
      (tag) => tag.displayLabel == displayLabel,
    );
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

class _ThemeOptionCard extends StatelessWidget {
  const _ThemeOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SelectionCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      isSelected: isSelected,
      onTap: onTap,
    );
  }
}
