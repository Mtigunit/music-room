import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:music_room/core/widgets/app_button.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/core/widgets/form_input_decoration.dart';
import 'package:music_room/core/widgets/form_section_label.dart';
import 'package:music_room/core/widgets/genre_selection_grid.dart';
import 'package:music_room/core/widgets/responsive_layout.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/auth/presentation/state/auth_state.dart';
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
        final layout = _ProfileLayout(screenSize);
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

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
                          _buildHeader(context, layout, theme, colorScheme),
                          SizedBox(height: layout.headerSpacing),
                          _buildResponsiveContent(context, layout, theme),
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

  Widget _buildHeader(
    BuildContext context,
    _ProfileLayout layout,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final username = _usernameFromAuthState(state);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthScreenHeader(
              title: 'Complete your profile',
              subtitle: 'Add a few details to personalize your experience.',
              titleFontSize: layout.titleFontSize,
              subtitleTopSpacing: layout.welcomeSpacing,
              bottomSpacing: 0,
            ),
            if (username != null) ...[
              SizedBox(height: layout.welcomeSpacing),
              Text(
                'Welcome, @$username',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: layout.welcomeFontSize,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildResponsiveContent(
    BuildContext context,
    _ProfileLayout layout,
    ThemeData theme,
  ) {
    return switch (layout.screenSize) {
      ScreenSize.compact => _buildCompactContent(context, layout, theme),
      ScreenSize.medium => _buildCompactContent(context, layout, theme),
      ScreenSize.expanded => _buildExpandedContent(context, layout, theme),
    };
  }

  Widget _buildCompactContent(
    BuildContext context,
    _ProfileLayout layout,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProfileCard(context, layout),
        SizedBox(height: layout.sectionGap),
        _buildUsernameField(theme),
        SizedBox(height: layout.fieldGap),
        _buildBioField(theme),
        SizedBox(height: layout.fieldGap),
        _buildLocationField(theme),
        SizedBox(height: layout.sectionGap),
        _buildGenresSection(layout),
        SizedBox(height: layout.sectionGap),
        _buildThemeSection(layout),
        SizedBox(height: layout.sectionGap),
        _buildActions(layout),
      ],
    );
  }

  Widget _buildExpandedContent(
    BuildContext context,
    _ProfileLayout layout,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileCard(context, layout),
                  SizedBox(height: layout.sectionGap),
                  _buildThemeSection(layout),
                ],
              ),
            ),
            SizedBox(width: layout.columnsGap),
            Expanded(
              flex: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildUsernameField(theme)),
                      SizedBox(width: layout.fieldGap),
                      Expanded(child: _buildLocationField(theme)),
                    ],
                  ),
                  SizedBox(height: layout.fieldGap),
                  _buildBioField(theme),
                  SizedBox(height: layout.sectionGap),
                  _buildGenresSection(layout),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: layout.sectionGap),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: layout.actionsMaxWidth,
            child: _buildActions(layout),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(
    BuildContext context,
    _ProfileLayout layout,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: _isBusy ? null : _pickAvatar,
      borderRadius: BorderRadius.circular(layout.cardRadius),
      child: Container(
        padding: EdgeInsets.all(layout.cardPadding),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(layout.cardRadius),
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Builder(
              builder: (context) {
                final ImageProvider<Object>? avatarImage;

                if (_avatarUrl != null) {
                  avatarImage = NetworkImage(_avatarUrl!);
                } else if (_pickedAvatarBytes != null) {
                  avatarImage = MemoryImage(_pickedAvatarBytes!);
                } else {
                  avatarImage = null;
                }

                return CircleAvatar(
                  radius: layout.avatarRadius,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                  backgroundImage: avatarImage,
                  child: avatarImage == null
                      ? Icon(
                          Icons.add_a_photo_rounded,
                          color: colorScheme.primary,
                          size: layout.avatarIconSize,
                        )
                      : (_isUploadingAvatar
                            ? SizedBox(
                                width: layout.avatarLoaderSize,
                                height: layout.avatarLoaderSize,
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
            SizedBox(width: layout.cardInnerGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile photo',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: layout.sectionTitleFontSize,
                    ),
                  ),
                  SizedBox(height: layout.cardCopyGap),
                  Text(
                    _avatarUrl != null
                        ? 'Photo uploaded'
                        : (_pickedAvatarName == null
                              ? 'Tap to add a photo later from your profile.'
                              : 'Photo selected: ${_pickedAvatarName!}'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: layout.bodyFontSize,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: layout.cardInnerGap),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
              size: layout.chevronSize,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsernameField(ThemeData theme) {
    return TextFormField(
      controller: _usernameController,
      textInputAction: TextInputAction.next,
      decoration: FormInputDecoration.build(
        theme,
        labelText: null,
        hintText: 'Username',
      ),
      validator: _validateUsername,
    );
  }

  Widget _buildBioField(ThemeData theme) {
    return TextFormField(
      controller: _bioController,
      maxLines: 4,
      maxLength: 150,
      decoration: FormInputDecoration.build(
        theme,
        labelText: null,
        hintText: 'Tell people what you are into',
      ),
    );
  }

  Widget _buildLocationField(ThemeData theme) {
    return TextFormField(
      controller: _locationController,
      decoration: FormInputDecoration.build(
        theme,
        labelText: null,
        hintText: 'City or region',
      ),
    );
  }

  Widget _buildGenresSection(_ProfileLayout layout) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FormSectionLabel(text: 'Favorite genres'),
        SizedBox(height: layout.sectionLabelGap),
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
          spacing: layout.genreSpacing,
          runSpacing: layout.genreRunSpacing,
          onGenreTapped: _toggleGenre,
        ),
      ],
    );
  }

  Widget _buildThemeSection(_ProfileLayout layout) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FormSectionLabel(text: 'Theme preference'),
        SizedBox(height: layout.sectionLabelGap),
        _ThemeOptionCard(
          title: 'System',
          subtitle: 'Match the device appearance.',
          icon: Icons.brightness_auto_rounded,
          isSelected: _selectedTheme == 'SYSTEM',
          onTap: () => setState(() => _selectedTheme = 'SYSTEM'),
        ),
        SizedBox(height: layout.themeOptionGap),
        _ThemeOptionCard(
          title: 'Light',
          subtitle: 'Use the lighter visual mode.',
          icon: Icons.light_mode_rounded,
          isSelected: _selectedTheme == 'LIGHT',
          onTap: () => setState(() => _selectedTheme = 'LIGHT'),
        ),
        SizedBox(height: layout.themeOptionGap),
        _ThemeOptionCard(
          title: 'Dark',
          subtitle: 'Use the darker visual mode.',
          icon: Icons.dark_mode_rounded,
          isSelected: _selectedTheme == 'DARK',
          onTap: () => setState(() => _selectedTheme = 'DARK'),
        ),
      ],
    );
  }

  Widget _buildActions(_ProfileLayout layout) {
    final isCompact = layout.screenSize == ScreenSize.compact;

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
          SizedBox(height: layout.actionGap),
          AppButton(
            onPressed: _isBusy ? null : _skip,
            variant: AppButtonVariant.outlined,
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
        SizedBox(width: layout.actionGap),
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

    // Read bytes immediately so we can show a preview without importing dart:io
    final bytes = await avatar.readAsBytes();
    final avatarName = avatar.name;

    setState(() {
      _pickedAvatar = avatar;
      _pickedAvatarBytes = bytes;
      _pickedAvatarName = avatarName;
      _isUploadingAvatar = true;
      _avatarUrl = null;
    });

    try {
      final profileRepository = InjectionContainer().profileRepository;
      final updated = await profileRepository.uploadMyAvatar(
        bytes,
        avatarName,
      );

      if (!mounted) return;

      setState(() {
        _avatarUrl = updated.profile.avatarUrl;
        _pickedAvatar = null;
        _pickedAvatarBytes = null;
        _pickedAvatarName = null;
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

class _ProfileLayout {
  const _ProfileLayout(this.screenSize);

  final ScreenSize screenSize;

  bool get isCompact => screenSize == ScreenSize.compact;

  double get horizontalPadding => switch (screenSize) {
    ScreenSize.compact => 16,
    ScreenSize.medium => 24,
    ScreenSize.expanded => 32,
  };

  double get verticalPadding => switch (screenSize) {
    ScreenSize.compact => 16,
    ScreenSize.medium => 24,
    ScreenSize.expanded => 28,
  };

  double get contentMaxWidth => switch (screenSize) {
    ScreenSize.compact => double.infinity,
    ScreenSize.medium => 980,
    ScreenSize.expanded => 1240,
  };

  double get headerSpacing => switch (screenSize) {
    ScreenSize.compact => 20,
    ScreenSize.medium => 24,
    ScreenSize.expanded => 28,
  };

  double get sectionGap => switch (screenSize) {
    ScreenSize.compact => 16,
    ScreenSize.medium => 20,
    ScreenSize.expanded => 24,
  };

  double get fieldGap => switch (screenSize) {
    ScreenSize.compact => 12,
    ScreenSize.medium => 14,
    ScreenSize.expanded => 16,
  };

  double get columnsGap => switch (screenSize) {
    ScreenSize.compact => 0,
    ScreenSize.medium => 24,
    ScreenSize.expanded => 32,
  };

  double get actionGap => switch (screenSize) {
    ScreenSize.compact => 12,
    ScreenSize.medium => 14,
    ScreenSize.expanded => 16,
  };

  double get sectionLabelGap => switch (screenSize) {
    ScreenSize.compact => 10,
    ScreenSize.medium => 12,
    ScreenSize.expanded => 12,
  };

  double get themeOptionGap => switch (screenSize) {
    ScreenSize.compact => 10,
    ScreenSize.medium => 12,
    ScreenSize.expanded => 12,
  };

  double get genreSpacing => switch (screenSize) {
    ScreenSize.compact => 10,
    ScreenSize.medium => 12,
    ScreenSize.expanded => 14,
  };

  double get genreRunSpacing => switch (screenSize) {
    ScreenSize.compact => 10,
    ScreenSize.medium => 12,
    ScreenSize.expanded => 14,
  };

  double get titleFontSize => switch (screenSize) {
    ScreenSize.compact => 28,
    ScreenSize.medium => 32,
    ScreenSize.expanded => 36,
  };

  double get subtitleFontSize => switch (screenSize) {
    ScreenSize.compact => 16,
    ScreenSize.medium => 17,
    ScreenSize.expanded => 18,
  };

  double get welcomeSpacing => switch (screenSize) {
    ScreenSize.compact => 8,
    ScreenSize.medium => 10,
    ScreenSize.expanded => 12,
  };

  double get welcomeFontSize => switch (screenSize) {
    ScreenSize.compact => 16,
    ScreenSize.medium => 17,
    ScreenSize.expanded => 18,
  };

  double get cardPadding => switch (screenSize) {
    ScreenSize.compact => 16,
    ScreenSize.medium => 18,
    ScreenSize.expanded => 20,
  };

  double get cardRadius => switch (screenSize) {
    ScreenSize.compact => 20,
    ScreenSize.medium => 20,
    ScreenSize.expanded => 22,
  };

  double get cardInnerGap => switch (screenSize) {
    ScreenSize.compact => 12,
    ScreenSize.medium => 14,
    ScreenSize.expanded => 16,
  };

  double get cardCopyGap => switch (screenSize) {
    ScreenSize.compact => 4,
    ScreenSize.medium => 4,
    ScreenSize.expanded => 6,
  };

  double get bodyFontSize => switch (screenSize) {
    ScreenSize.compact => 14,
    ScreenSize.medium => 15,
    ScreenSize.expanded => 15,
  };

  double get sectionTitleFontSize => switch (screenSize) {
    ScreenSize.compact => 16,
    ScreenSize.medium => 16,
    ScreenSize.expanded => 17,
  };

  double get avatarRadius => switch (screenSize) {
    ScreenSize.compact => 28,
    ScreenSize.medium => 30,
    ScreenSize.expanded => 32,
  };

  double get avatarIconSize => switch (screenSize) {
    ScreenSize.compact => 24,
    ScreenSize.medium => 24,
    ScreenSize.expanded => 26,
  };

  double get avatarLoaderSize => switch (screenSize) {
    ScreenSize.compact => 20,
    ScreenSize.medium => 22,
    ScreenSize.expanded => 22,
  };

  double get chevronSize => switch (screenSize) {
    ScreenSize.compact => 22,
    ScreenSize.medium => 22,
    ScreenSize.expanded => 24,
  };

  double get actionsMaxWidth => switch (screenSize) {
    ScreenSize.compact => double.infinity,
    ScreenSize.medium => 520,
    ScreenSize.expanded => 560,
  };
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
