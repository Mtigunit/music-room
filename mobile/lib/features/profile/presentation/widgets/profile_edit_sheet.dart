import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/widgets/app_back_button.dart';
import 'package:music_room/core/widgets/app_button.dart';
import 'package:music_room/core/widgets/confirmation_dialog.dart';
import 'package:music_room/core/widgets/form_input_decoration.dart';
import 'package:music_room/core/widgets/form_section_label.dart';
import 'package:music_room/core/widgets/form_toggle_row.dart';
import 'package:music_room/core/widgets/genre_selection_grid.dart';
import 'package:music_room/core/widgets/responsive_layout.dart';
import 'package:music_room/features/events/presentation/widgets/selection_card.dart';
import 'package:music_room/features/playlist/domain/types/playlist_tags.dart';
import 'package:music_room/features/profile/domain/entities/profile_entity.dart';
import 'package:music_room/features/profile/presentation/pages/email_update_page.dart';
import 'package:music_room/features/profile/presentation/state/profile_bloc.dart';
import 'package:music_room/features/profile/presentation/state/profile_event.dart';
import 'package:music_room/features/profile/presentation/state/profile_state.dart';

class ProfileEditSheet extends StatefulWidget {
  const ProfileEditSheet({required this.profile, super.key});

  final UserProfileEntity profile;

  @override
  State<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<ProfileEditSheet> {
  final GlobalKey<FormState> _profileFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _securityFormKey = GlobalKey<FormState>();
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profileState = context.watch<ProfileBloc>().state;
    final currentProfile = _profileFromState(profileState);

    final isDesktop =
        MediaQuery.of(context).size.width >=
        ResponsiveLayout.expandedBreakpoint;

    return SafeArea(
      child: BlocListener<ProfileBloc, ProfileState>(
        listenWhen: (previous, current) =>
            current is ProfilePasswordChangeSuccess ||
            current is ProfileGoogleLinkSuccess ||
            current is ProfileGoogleUnlinkSuccess,
        listener: (context, state) {
          if (state is ProfilePasswordChangeSuccess) {
            _clearSecurityForm();
          }

          if (state is ProfileGoogleLinkSuccess ||
              state is ProfileGoogleUnlinkSuccess) {
            setState(() {});
          }
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            isDesktop ? 20 : 12,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle — only relevant inside a bottom sheet.
                    if (!isDesktop)
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colorScheme.onSurface.withValues(
                              alpha: 0.18,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    if (!isDesktop) const SizedBox(height: 20),
                    Row(
                      children: [
                        if (isDesktop)
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: theme.colorScheme.onSurface,
                            ),
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(context).pop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                          )
                        else
                          AppBackButton(
                            color: theme.colorScheme.onSurface,
                            padding: EdgeInsets.zero,
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Edit profile',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Update your account, preferences, '
                                'and security settings.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Form(
                key: _profileFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionCard(
                      context: context,
                      title: 'Account',
                      subtitle: 'Keep your identity current.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _usernameController,
                            textInputAction: TextInputAction.next,
                            decoration: FormInputDecoration.build(
                              theme,
                              labelText: null,
                              hintText: 'Choose a username',
                            ),
                            validator: _validateUsername,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Email',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        currentProfile.email ?? 'Not set',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color:
                                                  theme.colorScheme.onSurface,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                AppButton(
                                  onPressed: () async {
                                    final profileBloc = context
                                        .read<ProfileBloc>();
                                    final result =
                                        await Navigator.of(
                                          context,
                                        ).push<bool>(
                                          MaterialPageRoute<bool>(
                                            builder: (_) =>
                                                const EmailUpdatePage(),
                                          ),
                                        );

                                    if (result == true && mounted) {
                                      profileBloc.add(
                                        const ProfileRefreshRequested(),
                                      );
                                    }
                                  },
                                  variant: AppButtonVariant.text,
                                  label: 'Change email',
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      context: context,
                      title: 'Profile details',
                      subtitle:
                          'Share the details friends see on your profile.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _bioController,
                            maxLength: 150,
                            maxLines: 4,
                            decoration: FormInputDecoration.build(
                              theme,
                              labelText: null,
                              hintText: 'Tell people about your vibe',
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _locationController,
                            decoration: FormInputDecoration.build(
                              theme,
                              labelText: null,
                              hintText: 'City or region',
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _dateOfBirthController,
                            decoration: FormInputDecoration.build(
                              theme,
                              labelText: null,
                              hintText: 'YYYY-MM-DD',
                              suffixIcon: IconButton(
                                icon: const Icon(
                                  Icons.calendar_month_rounded,
                                ),
                                onPressed: () => _pickDate(context),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _physicalAddressController,
                            maxLines: 2,
                            decoration: FormInputDecoration.build(
                              theme,
                              labelText: null,
                              hintText: 'Optional address or venue area',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      context: context,
                      title: 'Preferences',
                      subtitle: 'Control how your profile and app look.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FormToggleRow(
                            title: 'Auto accept invites',
                            subtitle: _autoAcceptInvites
                                ? 'Automatically accept room and '
                                      'playlist invitations'
                                : 'Review invitations before accepting',
                            value: _autoAcceptInvites,
                            onChanged: (value) {
                              setState(() {
                                _autoAcceptInvites = value;
                              });
                            },
                          ),
                          const SizedBox(height: 20),
                          const FormSectionLabel(text: 'FAVORITE GENRES'),
                          const SizedBox(height: 10),
                          GenreSelectionGrid(
                            genres: PlaylistTag.all
                                .map((tag) => tag.displayLabel)
                                .toList(growable: false),
                            selectedGenres: _favoriteGenres
                                .map(
                                  (value) => PlaylistTag.fromValue(
                                    value,
                                  )?.displayLabel,
                                )
                                .whereType<String>()
                                .toList(growable: false),
                            onGenreTapped: (displayLabel) {
                              final tag = PlaylistTag.all.firstWhere(
                                (item) => item.displayLabel == displayLabel,
                              );

                              setState(() {
                                if (_favoriteGenres.contains(tag.value)) {
                                  _favoriteGenres.remove(tag.value);
                                } else {
                                  _favoriteGenres.add(tag.value);
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 20),
                          const FormSectionLabel(text: 'THEME PREFERENCE'),
                          const SizedBox(height: 10),
                          SelectionCard(
                            title: 'Light',
                            subtitle: 'Always use light theme',
                            icon: Icons.light_mode,
                            isSelected: _themeController.text == 'LIGHT',
                            onTap: () {
                              setState(() {
                                _themeController.text = 'LIGHT';
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          SelectionCard(
                            title: 'Dark',
                            subtitle: 'Always use dark theme',
                            icon: Icons.dark_mode,
                            isSelected: _themeController.text == 'DARK',
                            onTap: () {
                              setState(() {
                                _themeController.text = 'DARK';
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          SelectionCard(
                            title: 'System',
                            subtitle: 'Follow device settings',
                            icon: Icons.settings_suggest,
                            isSelected: _themeController.text == 'SYSTEM',
                            onTap: () {
                              setState(() {
                                _themeController.text = 'SYSTEM';
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        onPressed: _handleProfileSave,
                        label: 'Save changes',
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Form(
                key: _securityFormKey,
                child: BlocBuilder<ProfileBloc, ProfileState>(
                  buildWhen: (previous, current) =>
                      current is ProfilePasswordChangeInProgress ||
                      current is ProfilePasswordChangeSuccess ||
                      current is ProfilePasswordChangeFailure ||
                      current is ProfileGoogleLinkInProgress ||
                      current is ProfileGoogleLinkSuccess ||
                      current is ProfileGoogleLinkFailure ||
                      current is ProfileGoogleUnlinkInProgress ||
                      current is ProfileGoogleUnlinkSuccess ||
                      current is ProfileGoogleUnlinkFailure,
                  builder: (context, state) {
                    final isPasswordLoading =
                        state is ProfilePasswordChangeInProgress;
                    final isGoogleLinkLoading =
                        state is ProfileGoogleLinkInProgress ||
                        state is ProfileGoogleUnlinkInProgress;
                    final googleLinkStatus = _googleLinkStatusFromState(state);

                    return _buildSectionCard(
                      context: context,
                      title: 'Security',
                      subtitle: 'Change your password safely.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPasswordField(
                            controller: _currentPasswordController,
                            label: 'Current password',
                            hintText: 'Enter current password',
                            obscureText: _obscureCurrentPassword,
                            enabled: !isPasswordLoading,
                            textInputAction: TextInputAction.next,
                            validator: _validateCurrentPassword,
                            onToggleVisibility: () {
                              setState(() {
                                _obscureCurrentPassword =
                                    !_obscureCurrentPassword;
                              });
                            },
                          ),
                          const SizedBox(height: 20),
                          _buildPasswordField(
                            controller: _newPasswordController,
                            label: 'New password',
                            hintText: 'Enter a new password',
                            obscureText: _obscureNewPassword,
                            enabled: !isPasswordLoading,
                            textInputAction: TextInputAction.next,
                            validator: _validateNewPassword,
                            onChanged: (_) {
                              if (_confirmPasswordController.text.isNotEmpty) {
                                _securityFormKey.currentState?.validate();
                              }
                            },
                            onToggleVisibility: () {
                              setState(() {
                                _obscureNewPassword = !_obscureNewPassword;
                              });
                            },
                          ),
                          const SizedBox(height: 20),
                          _buildPasswordField(
                            controller: _confirmPasswordController,
                            label: 'Confirm new password',
                            hintText: 'Repeat the new password',
                            obscureText: _obscureConfirmPassword,
                            enabled: !isPasswordLoading,
                            textInputAction: TextInputAction.done,
                            validator: _validateConfirmPassword,
                            onFieldSubmitted: (_) => _handlePasswordChange(),
                            onToggleVisibility: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: AppButton(
                              onPressed: isPasswordLoading
                                  ? null
                                  : _handlePasswordChange,
                              isLoading: isPasswordLoading,
                              label: 'Change password',
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _GoogleLinkStatusCard(
                            status: googleLinkStatus,
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: AppButton(
                              onPressed: isGoogleLinkLoading
                                  ? null
                                  : _handleGoogleAccountLink,
                              isLoading: isGoogleLinkLoading,
                              label: googleLinkStatus == GoogleLinkStatus.linked
                                  ? 'Remove Google Link'
                                  : 'Link Google account',
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.3 : 0.62,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required bool obscureText,
    required bool enabled,
    required TextInputAction textInputAction,
    required String? Function(String?) validator,
    required VoidCallback onToggleVisibility,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onFieldSubmitted,
  }) {
    final theme = Theme.of(context);

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      textInputAction: textInputAction,
      autocorrect: false,
      enableSuggestions: false,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      decoration: FormInputDecoration.build(
        theme,
        labelText: null,
        hintText: hintText,
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: onToggleVisibility,
        ),
      ),
      validator: validator,
    );
  }

  void _handleProfileSave() {
    final isValid = _profileFormKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    Navigator.of(context).pop(
      ProfileUpdateRequest(
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
    final isValid = _securityFormKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    context.read<ProfileBloc>().add(
      ProfilePasswordChangeRequested(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      ),
    );
  }

  Future<void> _handleGoogleAccountLink() async {
    final status = _googleLinkStatusFromState(
      context.read<ProfileBloc>().state,
    );

    if (status == GoogleLinkStatus.linked) {
      await _confirmGoogleUnlink();
      return;
    }

    context.read<ProfileBloc>().add(const ProfileGoogleLinkRequested());
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
      context.read<ProfileBloc>().add(const ProfileGoogleUnlinkRequested());
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

    _securityFormKey.currentState?.reset();
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

  UserProfileEntity _profileFromState(ProfileState state) {
    if (state is ProfileLoaded) {
      return state.data.profile;
    }
    if (state is ProfileMutationInProgress) {
      return state.data.profile;
    }
    if (state is ProfileMutationSuccess) {
      return state.data.profile;
    }
    if (state is ProfileMutationFailure) {
      return state.data.profile;
    }
    if (state is ProfilePasswordChangeInProgress) {
      return state.data.profile;
    }
    if (state is ProfilePasswordChangeSuccess) {
      return state.data.profile;
    }
    if (state is ProfilePasswordChangeFailure) {
      return state.data.profile;
    }
    if (state is ProfileGoogleLinkInProgress) {
      return state.data.profile;
    }
    if (state is ProfileGoogleLinkSuccess) {
      return state.data.profile;
    }
    if (state is ProfileGoogleLinkFailure) {
      return state.data.profile;
    }
    if (state is ProfileGoogleUnlinkInProgress) {
      return state.data.profile;
    }
    if (state is ProfileGoogleUnlinkSuccess) {
      return state.data.profile;
    }
    if (state is ProfileGoogleUnlinkFailure) {
      return state.data.profile;
    }

    return widget.profile;
  }

  List<String> _readGenres(Map<String, dynamic>? source) {
    final rawGenres =
        source?['favoriteGenres'] ?? source?['genres'] ?? source?['tags'];
    if (rawGenres is List<dynamic>) {
      return rawGenres
          .whereType<String>()
          .map((item) => item.toUpperCase())
          .toList(growable: false);
    }
    return const <String>[];
  }

  bool _readBool(Map<String, dynamic>? source, String key) {
    final value = source?[key];
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }

    return false;
  }

  GoogleLinkStatus _googleLinkStatusFromState(ProfileState state) {
    if (state is ProfileLoaded) {
      return state.data.profile.googleLinkStatus;
    }
    if (state is ProfileMutationInProgress) {
      return state.data.profile.googleLinkStatus;
    }
    if (state is ProfileMutationSuccess) {
      return state.data.profile.googleLinkStatus;
    }
    if (state is ProfileMutationFailure) {
      return state.data.profile.googleLinkStatus;
    }
    if (state is ProfilePasswordChangeInProgress) {
      return state.data.profile.googleLinkStatus;
    }
    if (state is ProfilePasswordChangeSuccess) {
      return state.data.profile.googleLinkStatus;
    }
    if (state is ProfilePasswordChangeFailure) {
      return state.data.profile.googleLinkStatus;
    }
    if (state is ProfileGoogleLinkInProgress) {
      return state.data.profile.googleLinkStatus;
    }
    if (state is ProfileGoogleLinkSuccess) {
      return state.data.profile.googleLinkStatus;
    }
    if (state is ProfileGoogleLinkFailure) {
      return state.data.profile.googleLinkStatus;
    }
    if (state is ProfileGoogleUnlinkInProgress) {
      return state.data.profile.googleLinkStatus;
    }
    if (state is ProfileGoogleUnlinkSuccess) {
      return state.data.profile.googleLinkStatus;
    }
    if (state is ProfileGoogleUnlinkFailure) {
      return state.data.profile.googleLinkStatus;
    }
    return widget.profile.googleLinkStatus;
  }

  String? _validateUsername(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Username is required';
    }
    if (trimmed.length < 3 || trimmed.length > 30) {
      return 'Username must be 3 to 30 characters';
    }
    final usernamePattern = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernamePattern.hasMatch(trimmed)) {
      return 'Use only letters, numbers, and underscores';
    }
    return null;
  }
}

class _GoogleLinkStatusCard extends StatelessWidget {
  const _GoogleLinkStatusCard({required this.status});

  final GoogleLinkStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final icon = switch (status) {
      GoogleLinkStatus.linked => Icons.link_rounded,
      GoogleLinkStatus.unlinked => Icons.link_off_rounded,
      GoogleLinkStatus.unknown => Icons.help_outline_rounded,
    };

    final label = switch (status) {
      GoogleLinkStatus.linked => 'Linked',
      GoogleLinkStatus.unlinked => 'Not linked',
      GoogleLinkStatus.unknown => 'Status unavailable',
    };

    final helper = switch (status) {
      GoogleLinkStatus.linked =>
        'Your account has an active Google sign-in link.',
      GoogleLinkStatus.unlinked => 'No Google account is currently linked.',
      GoogleLinkStatus.unknown =>
        'This app cannot fetch Google link status from the server.',
    };

    final accent = switch (status) {
      GoogleLinkStatus.linked => colorScheme.primary,
      GoogleLinkStatus.unlinked => colorScheme.error,
      GoogleLinkStatus.unknown => colorScheme.secondary,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Google account: $label',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  helper,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
