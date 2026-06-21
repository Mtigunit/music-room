import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/utils/tag_genre_normalizer.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/core/widgets/confirmation_dialog.dart';
import 'package:music_room/core/widgets/responsive_layout.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/auth/presentation/state/auth_event.dart';
import 'package:music_room/features/auth/presentation/state/auth_state.dart';
import 'package:music_room/features/profile/domain/entities/profile_entity.dart';
import 'package:music_room/features/profile/presentation/widgets/profile_edit_header.dart';
import 'package:music_room/features/settings/domain/entities/settings_update_request.dart';
import 'package:music_room/features/settings/presentation/state/settings_bloc.dart';
import 'package:music_room/features/settings/presentation/state/settings_event.dart';
import 'package:music_room/features/settings/presentation/state/settings_state.dart';
import 'package:music_room/features/settings/presentation/widgets/profile_edit_form.dart';
import 'package:music_room/features/settings/presentation/widgets/profile_edit_security_form.dart';

class ProfileEditSheet extends StatefulWidget {
  const ProfileEditSheet({
    required this.profile,
    required this.onSaveRequested,
    this.showDragHandle = true,
    this.showBackButton = true,
    this.isSaving = false,
    super.key,
  });

  final UserProfileEntity profile;
  final bool showDragHandle;
  final bool showBackButton;
  final ValueChanged<SettingsUpdateRequest> onSaveRequested;
  final bool isSaving;

  @override
  State<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<ProfileEditSheet> {
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  late final TextEditingController _locationController;
  late final TextEditingController _dateOfBirthController;
  late final TextEditingController _physicalAddressController;
  late final TextEditingController _themeController;
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;
  late final Set<String> _favoriteGenres;
  bool _autoAcceptInvites = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.profile.username);
    _bioController = TextEditingController(
      text: _readString(widget.profile.publicInfo, 'shortBio'),
    );
    _locationController = TextEditingController(
      text: _readString(widget.profile.friendInfo, 'location'),
    );
    _dateOfBirthController = TextEditingController(
      text: _readString(widget.profile.privateInfo, 'dateOfBirth'),
    );
    _physicalAddressController = TextEditingController(
      text: _readString(widget.profile.privateInfo, 'physicalAddress'),
    );
    _themeController = TextEditingController(
      text: _readString(widget.profile.preferences, 'uiTheme'),
    );
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _favoriteGenres = _readGenres(widget.profile.preferences).toSet();
    _autoAcceptInvites = _readBool(
      widget.profile.preferences,
      'autoAcceptInvites',
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _dateOfBirthController.dispose();
    _physicalAddressController.dispose();
    _themeController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileState = context.watch<SettingsBloc>().state;
    final currentProfile = _profileFromState(profileState);

    return SafeArea(
      child: IgnorePointer(
        ignoring: widget.isSaving,
        child: MultiBlocListener(
          listeners: [
            BlocListener<SettingsBloc, SettingsState>(
              listenWhen: (previous, current) =>
                  current is SettingsPasswordChangeSuccess ||
                  current is SettingsGoogleLinkSuccess ||
                  current is SettingsGoogleUnlinkSuccess,
              listener: (context, state) {
                if (state is SettingsPasswordChangeSuccess) {
                  _clearSecurityForm();
                }

                if (state is SettingsGoogleLinkSuccess ||
                    state is SettingsGoogleUnlinkSuccess) {
                  setState(() {});
                }
              },
            ),
            BlocListener<AuthBloc, AuthState>(
              listenWhen: (previous, current) => current is LogoutFailure,
              listener: (context, state) {
                if (state is LogoutFailure) {
                  AppSnackbar.showError(context, state.failure.message);
                }
              },
            ),
          ],
          child: ResponsiveLayout(
            builder: (context, size) {
              return _buildResponsiveContent(
                context,
                size,
                currentProfile,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveContent(
    BuildContext context,
    ScreenSize size,
    UserProfileEntity currentProfile,
  ) {
    final isDesktop = size == ScreenSize.expanded;
    final isTablet = size == ScreenSize.medium;

    final horizontalPadding = isDesktop ? 48.0 : (isTablet ? 32.0 : 20.0);
    final topPadding = isDesktop ? 32.0 : 20.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        topPadding,
        horizontalPadding,
        MediaQuery.viewInsetsOf(context).bottom + 40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfileEditHeader(
            size: size,
            showDragHandle: widget.showDragHandle,
            showBackButton: widget.showBackButton,
          ),
          const SizedBox(height: 24),
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildProfileEditForm(
                    context,
                    currentProfile,
                  ),
                ),
                const SizedBox(width: 48),
                Expanded(
                  child: _buildProfileEditSecurityForm(),
                ),
              ],
            )
          else ...[
            _buildProfileEditForm(context, currentProfile),
            const SizedBox(height: 24),
            _buildProfileEditSecurityForm(),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileEditForm(
    BuildContext context,
    UserProfileEntity currentProfile,
  ) {
    final isPremium =
        currentProfile.subscriptionTier.toUpperCase() == 'PREMIUM';

    return ProfileEditForm(
      currentProfile: currentProfile,
      usernameController: _usernameController,
      bioController: _bioController,
      locationController: _locationController,
      dateOfBirthController: _dateOfBirthController,
      physicalAddressController: _physicalAddressController,
      themeController: _themeController,
      autoAcceptInvites: _autoAcceptInvites,
      favoriteGenres: _favoriteGenres,
      isSaving: widget.isSaving,
      onSavePressed: _handleProfileSave,
      isLocked: !isPremium,
      onAutoAcceptInvitesChanged: isPremium
          ? (value) => setState(() => _autoAcceptInvites = value)
          : (value) {},
      onFavoriteGenreTapped: (displayLabel) {
        final tagValue = TagGenreNormalizer.toValue(displayLabel);
        if (tagValue == null) {
          return;
        }

        setState(() {
          if (_favoriteGenres.contains(tagValue)) {
            _favoriteGenres.remove(tagValue);
          } else {
            _favoriteGenres.add(tagValue);
          }
        });
      },
      onThemeSelected: (themeValue) {
        setState(() {
          _themeController.text = themeValue;
        });
      },
      onDatePicked: () => _pickDate(context),
      validateUsername: _validateUsername,
    );
  }

  Widget _buildProfileEditSecurityForm() {
    return ProfileEditSecurityForm(
      currentPasswordController: _currentPasswordController,
      newPasswordController: _newPasswordController,
      confirmPasswordController: _confirmPasswordController,
      obscureCurrentPassword: _obscureCurrentPassword,
      obscureNewPassword: _obscureNewPassword,
      obscureConfirmPassword: _obscureConfirmPassword,
      onToggleCurrentPasswordVisibility: () {
        setState(() {
          _obscureCurrentPassword = !_obscureCurrentPassword;
        });
      },
      onToggleNewPasswordVisibility: () {
        setState(() {
          _obscureNewPassword = !_obscureNewPassword;
        });
      },
      onToggleConfirmPasswordVisibility: () {
        setState(() {
          _obscureConfirmPassword = !_obscureConfirmPassword;
        });
      },
      onPasswordChangePressed: _handlePasswordChange,
      onGoogleAccountLinkPressed: _handleGoogleAccountLink,
      onLogoutFromAllDevicesPressed: _handleLogoutFromAllDevices,
      validateCurrentPassword: _validateCurrentPassword,
      validateNewPassword: _validateNewPassword,
      validateConfirmPassword: _validateConfirmPassword,
    );
  }

  void _handleProfileSave() {
    widget.onSaveRequested(
      SettingsUpdateRequest(
        username: _usernameController.text,
        shortBio: _bioController.text,
        location: _locationController.text,
        dateOfBirth: _dateOfBirthController.text,
        physicalAddress: _physicalAddressController.text,
        favoriteGenres: _favoriteGenres.toList(
          growable: false,
        ),
        autoAcceptInvites: _autoAcceptInvites,
        uiTheme: _themeController.text.isEmpty ? null : _themeController.text,
      ),
    );
  }

  void _handlePasswordChange() {
    context.read<SettingsBloc>().add(
      SettingsPasswordChangeRequested(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      ),
    );
  }

  Future<void> _handleGoogleAccountLink() async {
    final profileState = context.read<SettingsBloc>().state;
    final status =
        profileState.dataOrNull?.profile.googleLinkStatus ??
        widget.profile.googleLinkStatus;

    if (status == GoogleLinkStatus.linked) {
      await _confirmGoogleUnlink();
      return;
    }

    context.read<SettingsBloc>().add(const SettingsGoogleLinkRequested());
  }

  Future<void> _confirmGoogleUnlink() async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'Unlink Google Account?',
      message:
          'This will remove the Google connection from your account.\n\n'
          'You can link it again later from this screen.',
      confirmLabel: 'Remove Link',
      cancelLabel: 'Keep Linked',
      icon: Icons.link_off_rounded,
      variant: ConfirmationDialogVariant.destructive,
    );

    if (confirmed == true && mounted) {
      context.read<SettingsBloc>().add(const SettingsGoogleUnlinkRequested());
    }
  }

  Future<void> _handleLogoutFromAllDevices() async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'Log out from all devices?',
      message:
          'This will end every active session for your account, including '
          'this device. You will need to sign in again.',
      confirmLabel: 'Log out all',
      cancelLabel: 'Stay signed in',
      icon: Icons.logout_rounded,
      variant: ConfirmationDialogVariant.destructive,
    );

    if (confirmed == true && mounted) {
      context.read<AuthBloc>().add(const LogoutFromAllDevicesRequested());
    }
  }

  void _clearSecurityForm() {
    if (!mounted) {
      return;
    }

    setState(() {
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _obscureCurrentPassword = true;
      _obscureNewPassword = true;
      _obscureConfirmPassword = true;
    });
  }

  String? _validateCurrentPassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Current password is required';
    }
    if (password.length < 8) {
      return 'Current password must be at least 8 characters';
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'New password is required';
    }
    if (password.length < 8) {
      return 'At least 8 characters';
    }
    final passwordPattern = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
    );
    if (!passwordPattern.hasMatch(password)) {
      return 'Must include lowercase, uppercase, number, and special character';
    }
    if (password == _currentPasswordController.text) {
      return 'New password must be different from current password';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Confirm your new password';
    }
    if (password != _newPasswordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _pickDate(BuildContext context) async {
    final current = DateTime.tryParse(_dateOfBirthController.text);
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      initialDate: current ?? DateTime(2000),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _dateOfBirthController.text = selected.toIso8601String().split('T').first;
    });
  }

  String _readString(Map<String, dynamic>? source, String key) {
    final value = source?[key];
    return value is String ? value : '';
  }

  bool _readBool(Map<String, dynamic>? source, String key) {
    final value = source?[key];
    return value == true;
  }

  UserProfileEntity _profileFromState(SettingsState state) =>
      state.dataOrNull?.profile ?? widget.profile;

  List<String> _readGenres(Map<String, dynamic>? source) {
    final rawGenres =
        source?['favoriteGenres'] ?? source?['genres'] ?? source?['tags'];
    if (rawGenres is List<dynamic>) {
      return TagGenreNormalizer.normalizeValues(rawGenres);
    }
    return const <String>[];
  }

  String? _validateUsername(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Username is required';
    }
    if (trimmed.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (trimmed.length > 30) {
      return 'Username must be 30 characters or fewer';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(trimmed)) {
      return 'Use only letters, numbers, and underscores';
    }
    return null;
  }
}
