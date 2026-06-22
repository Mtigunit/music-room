import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/widgets/app_button.dart';
import 'package:music_room/core/widgets/form_input_decoration.dart';
import 'package:music_room/features/settings/presentation/state/settings_bloc.dart';
import 'package:music_room/features/settings/presentation/state/settings_state.dart';
import 'package:music_room/features/settings/presentation/widgets/logout_all_button.dart';
import 'package:music_room/features/settings/presentation/widgets/profile_edit_section_card.dart';

class ProfileEditSecurityForm extends StatefulWidget {
  const ProfileEditSecurityForm({
    required this.currentPasswordController,
    required this.newPasswordController,
    required this.confirmPasswordController,
    required this.obscureCurrentPassword,
    required this.obscureNewPassword,
    required this.obscureConfirmPassword,
    required this.onToggleCurrentPasswordVisibility,
    required this.onToggleNewPasswordVisibility,
    required this.onToggleConfirmPasswordVisibility,
    required this.onPasswordChangePressed,
    required this.onGoogleAccountLinkPressed,
    required this.onLogoutFromAllDevicesPressed,
    required this.validateCurrentPassword,
    required this.validateNewPassword,
    required this.validateConfirmPassword,
    super.key,
  });

  final TextEditingController currentPasswordController;
  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;
  final bool obscureCurrentPassword;
  final bool obscureNewPassword;
  final bool obscureConfirmPassword;
  final VoidCallback onToggleCurrentPasswordVisibility;
  final VoidCallback onToggleNewPasswordVisibility;
  final VoidCallback onToggleConfirmPasswordVisibility;
  final VoidCallback onPasswordChangePressed;
  final Future<void> Function() onGoogleAccountLinkPressed;
  final VoidCallback onLogoutFromAllDevicesPressed;
  final String? Function(String?) validateCurrentPassword;
  final String? Function(String?) validateNewPassword;
  final String? Function(String?) validateConfirmPassword;

  @override
  State<ProfileEditSecurityForm> createState() =>
      _ProfileEditSecurityFormState();
}

class _ProfileEditSecurityFormState extends State<ProfileEditSecurityForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: BlocBuilder<SettingsBloc, SettingsState>(
        buildWhen: (previous, current) =>
            current is SettingsLoaded ||
            current is SettingsMutationSuccess ||
            current is SettingsMutationFailure ||
            current is SettingsPasswordChangeInProgress ||
            current is SettingsPasswordChangeSuccess ||
            current is SettingsPasswordChangeFailure ||
            current is SettingsGoogleLinkInProgress ||
            current is SettingsGoogleLinkSuccess ||
            current is SettingsGoogleLinkFailure ||
            current is SettingsGoogleUnlinkInProgress ||
            current is SettingsGoogleUnlinkSuccess ||
            current is SettingsGoogleUnlinkFailure,
        builder: (context, state) {
          final isPasswordLoading = state is SettingsPasswordChangeInProgress;
          final isGoogleLinkLoading =
              state is SettingsGoogleLinkInProgress ||
              state is SettingsGoogleUnlinkInProgress;
          final isGoogleLinked = _isGoogleLinked(state);

          return ProfileEditSectionCard(
            title: 'Security',
            subtitle: 'Change your password safely.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPasswordField(
                  controller: widget.currentPasswordController,
                  hintText: 'Enter current password',
                  obscureText: widget.obscureCurrentPassword,
                  enabled: !isPasswordLoading,
                  textInputAction: TextInputAction.next,
                  validator: widget.validateCurrentPassword,
                  onToggleVisibility: widget.onToggleCurrentPasswordVisibility,
                ),
                const SizedBox(height: 20),
                _buildPasswordField(
                  controller: widget.newPasswordController,
                  hintText: 'Enter a new password',
                  obscureText: widget.obscureNewPassword,
                  enabled: !isPasswordLoading,
                  textInputAction: TextInputAction.next,
                  validator: widget.validateNewPassword,
                  onChanged: (_) {
                    if (widget.confirmPasswordController.text.isNotEmpty) {
                      _formKey.currentState?.validate();
                    }
                  },
                  onToggleVisibility: widget.onToggleNewPasswordVisibility,
                ),
                const SizedBox(height: 20),
                _buildPasswordField(
                  controller: widget.confirmPasswordController,
                  hintText: 'Repeat the new password',
                  obscureText: widget.obscureConfirmPassword,
                  enabled: !isPasswordLoading,
                  textInputAction: TextInputAction.done,
                  validator: widget.validateConfirmPassword,
                  onFieldSubmitted: (_) {
                    if (_formKey.currentState?.validate() ?? false) {
                      widget.onPasswordChangePressed();
                    }
                  },
                  onToggleVisibility: widget.onToggleConfirmPasswordVisibility,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    onPressed: isPasswordLoading
                        ? null
                        : () {
                            if (_formKey.currentState?.validate() ?? false) {
                              widget.onPasswordChangePressed();
                            }
                          },
                    isLoading: isPasswordLoading,
                    label: 'Change password',
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 20),
                _GoogleLinkStatusCard(isLinked: isGoogleLinked),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    onPressed: isGoogleLinkLoading
                        ? null
                        : widget.onGoogleAccountLinkPressed,
                    isLoading: isGoogleLinkLoading,
                    label: isGoogleLinked
                        ? 'Remove Google Link'
                        : 'Link Google account',
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 20),
                LogoutAllButton(
                  onLogout: widget.onLogoutFromAllDevicesPressed,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
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

  bool _isGoogleLinked(SettingsState state) =>
      state.dataOrNull?.profile.isGoogleLinked ?? false;
}

class _GoogleLinkStatusCard extends StatelessWidget {
  const _GoogleLinkStatusCard({required this.isLinked});

  final bool isLinked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final icon = isLinked ? Icons.link_rounded : Icons.link_off_rounded;

    final label = isLinked ? 'Linked' : 'Not linked';

    final helper = isLinked
        ? 'Your account has an active Google sign-in link.'
        : 'No Google account is currently linked.';

    final accent = isLinked ? colorScheme.primary : colorScheme.error;

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
