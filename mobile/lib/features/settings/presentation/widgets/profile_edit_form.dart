import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/utils/tag_genre_normalizer.dart';
import 'package:music_room/core/widgets/app_button.dart';
import 'package:music_room/core/widgets/form_input_decoration.dart';
import 'package:music_room/core/widgets/form_section_label.dart';
import 'package:music_room/core/widgets/form_toggle_row.dart';
import 'package:music_room/core/widgets/genre_selection_grid.dart';
import 'package:music_room/features/events/presentation/widgets/selection_card.dart';
import 'package:music_room/features/profile/domain/entities/profile_entity.dart';
import 'package:music_room/features/settings/presentation/pages/email_update_page.dart';
import 'package:music_room/features/settings/presentation/state/settings_bloc.dart';
import 'package:music_room/features/settings/presentation/state/settings_event.dart';
import 'package:music_room/features/settings/presentation/widgets/profile_edit_section_card.dart';

class ProfileEditForm extends StatefulWidget {
  const ProfileEditForm({
    required this.currentProfile,
    required this.usernameController,
    required this.bioController,
    required this.locationController,
    required this.dateOfBirthController,
    required this.physicalAddressController,
    required this.themeController,
    required this.autoAcceptInvites,
    required this.favoriteGenres,
    required this.isSaving,
    required this.onSavePressed,
    required this.onAutoAcceptInvitesChanged,
    required this.onFavoriteGenreTapped,
    required this.onThemeSelected,
    required this.onDatePicked,
    required this.validateUsername,
    this.isLocked = false,
    super.key,
  });

  final UserProfileEntity currentProfile;
  final TextEditingController usernameController;
  final TextEditingController bioController;
  final TextEditingController locationController;
  final TextEditingController dateOfBirthController;
  final TextEditingController physicalAddressController;
  final TextEditingController themeController;
  final bool autoAcceptInvites;
  final Set<String> favoriteGenres;
  final bool isSaving;
  final VoidCallback onSavePressed;
  final ValueChanged<bool> onAutoAcceptInvitesChanged;
  final ValueChanged<String> onFavoriteGenreTapped;
  final ValueChanged<String> onThemeSelected;
  final Future<void> Function() onDatePicked;
  final String? Function(String?) validateUsername;
  final bool isLocked;

  @override
  State<ProfileEditForm> createState() => _ProfileEditFormState();
}

class _ProfileEditFormState extends State<ProfileEditForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfileEditSectionCard(
            title: 'Account',
            subtitle: 'Keep your identity current.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: widget.usernameController,
                  textInputAction: TextInputAction.next,
                  decoration: FormInputDecoration.build(
                    theme,
                    labelText: null,
                    hintText: 'Choose a username',
                  ),
                  validator: widget.validateUsername,
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Email',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.currentProfile.email ?? 'Not set',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      AppButton(
                        onPressed: () async {
                          final settingsBloc = context.read<SettingsBloc>();
                          final result = await Navigator.of(context).push<bool>(
                            MaterialPageRoute<bool>(
                              builder: (_) => const EmailUpdatePage(),
                            ),
                          );

                          if (result == true && context.mounted) {
                            settingsBloc.add(const SettingsRefreshRequested());
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
          ProfileEditSectionCard(
            title: 'Profile details',
            subtitle: 'Share the details friends see on your profile.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: widget.bioController,
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
                  controller: widget.locationController,
                  decoration: FormInputDecoration.build(
                    theme,
                    labelText: null,
                    hintText: 'City or region',
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: widget.dateOfBirthController,
                  decoration: FormInputDecoration.build(
                    theme,
                    labelText: null,
                    hintText: 'YYYY-MM-DD',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_month_rounded),
                      onPressed: () => widget.onDatePicked(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: widget.physicalAddressController,
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
          ProfileEditSectionCard(
            title: 'Preferences',
            subtitle: 'Control how your profile and app look.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FormToggleRow(
                  title: 'Auto accept invites',
                  subtitle: widget.isLocked
                      ? 'Enabled and managed by the application'
                      : widget.autoAcceptInvites
                      ? 'Automatically accept room and playlist invitations'
                      : 'Review invitations before accepting',
                  value: widget.autoAcceptInvites,
                  onChanged: widget.onAutoAcceptInvitesChanged,
                  enabled: !widget.isLocked,
                  leading: widget.isLocked
                      ? Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.45,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 20),
                const FormSectionLabel(text: 'FAVORITE GENRES'),
                const SizedBox(height: 10),
                GenreSelectionGrid(
                  genres: TagGenreNormalizer.allDisplayLabels,
                  selectedGenres: TagGenreNormalizer.toDisplayLabels(
                    widget.favoriteGenres,
                  ),
                  onGenreTapped: widget.onFavoriteGenreTapped,
                ),
                const SizedBox(height: 20),
                const FormSectionLabel(text: 'THEME PREFERENCE'),
                const SizedBox(height: 10),
                SelectionCard(
                  title: 'Light',
                  subtitle: 'Always use light theme',
                  icon: Icons.light_mode,
                  isSelected: widget.themeController.text == 'LIGHT',
                  onTap: () => widget.onThemeSelected('LIGHT'),
                ),
                const SizedBox(height: 10),
                SelectionCard(
                  title: 'Dark',
                  subtitle: 'Always use dark theme',
                  icon: Icons.dark_mode,
                  isSelected: widget.themeController.text == 'DARK',
                  onTap: () => widget.onThemeSelected('DARK'),
                ),
                const SizedBox(height: 10),
                SelectionCard(
                  title: 'System',
                  subtitle: 'Follow device settings',
                  icon: Icons.settings_suggest,
                  isSelected: widget.themeController.text == 'SYSTEM',
                  onTap: () => widget.onThemeSelected('SYSTEM'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              onPressed: widget.isSaving
                  ? null
                  : () {
                      if (_formKey.currentState?.validate() ?? false) {
                        widget.onSavePressed();
                      }
                    },
              isLoading: widget.isSaving,
              label: 'Save changes',
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
