import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/form_input_decoration.dart';
import 'package:music_room/core/widgets/form_section_label.dart';
import 'package:music_room/core/widgets/genre_selection_grid.dart';
import 'package:music_room/core/widgets/responsive_layout.dart';
import 'package:music_room/features/auth/presentation/layouts/post_registration_profile_layout.dart';
import 'package:music_room/features/events/presentation/widgets/selection_card.dart';
import 'package:music_room/features/playlist/domain/types/playlist_tags.dart';

class ProfileFormSections extends StatelessWidget {
  const ProfileFormSections({
    required this.layout,
    required this.theme,
    required this.usernameController,
    required this.bioController,
    required this.locationController,
    required this.selectedGenres,
    required this.selectedTheme,
    required this.onGenreTapped,
    required this.onThemeChanged,
    this.usernameValidator,
    super.key,
  });

  final ProfileLayout layout;
  final ThemeData theme;
  final TextEditingController usernameController;
  final TextEditingController bioController;
  final TextEditingController locationController;
  final Set<String> selectedGenres;
  final String selectedTheme;
  final ValueChanged<String> onGenreTapped;
  final ValueChanged<String> onThemeChanged;
  final FormFieldValidator<String>? usernameValidator;

  @override
  Widget build(BuildContext context) {
    return switch (layout.screenSize) {
      ScreenSize.compact => _buildCompactContent(),
      ScreenSize.medium => _buildCompactContent(),
      ScreenSize.expanded => _buildExpandedContent(),
    };
  }

  Widget _buildCompactContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUsernameField(),
        SizedBox(height: layout.fieldGap),
        _buildBioField(),
        SizedBox(height: layout.fieldGap),
        _buildLocationField(),
        SizedBox(height: layout.sectionGap),
        _buildGenresSection(),
        SizedBox(height: layout.sectionGap),
        _buildThemeSection(),
      ],
    );
  }

  Widget _buildExpandedContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: _buildThemeSection(),
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
                  Expanded(child: _buildUsernameField()),
                  SizedBox(width: layout.fieldGap),
                  Expanded(child: _buildLocationField()),
                ],
              ),
              SizedBox(height: layout.fieldGap),
              _buildBioField(),
              SizedBox(height: layout.sectionGap),
              _buildGenresSection(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUsernameField() {
    return TextFormField(
      controller: usernameController,
      textInputAction: TextInputAction.next,
      decoration: FormInputDecoration.build(
        theme,
        labelText: null,
        hintText: 'Username',
      ),
      validator: usernameValidator,
    );
  }

  Widget _buildBioField() {
    return TextFormField(
      controller: bioController,
      maxLines: 4,
      maxLength: 150,
      decoration: FormInputDecoration.build(
        theme,
        labelText: null,
        hintText: 'Tell people what you are into',
      ),
    );
  }

  Widget _buildLocationField() {
    return TextFormField(
      controller: locationController,
      decoration: FormInputDecoration.build(
        theme,
        labelText: null,
        hintText: 'City or region',
      ),
    );
  }

  Widget _buildGenresSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FormSectionLabel(text: 'Favorite genres'),
        SizedBox(height: layout.sectionLabelGap),
        GenreSelectionGrid(
          genres: PlaylistTag.all
              .map((tag) => tag.displayLabel)
              .toList(growable: false),
          selectedGenres: selectedGenres
              .map((value) => PlaylistTag.fromValue(value)?.displayLabel)
              .whereType<String>()
              .toList(growable: false),
          maxSelection: 4,
          spacing: layout.genreSpacing,
          runSpacing: layout.genreRunSpacing,
          onGenreTapped: onGenreTapped,
        ),
      ],
    );
  }

  Widget _buildThemeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FormSectionLabel(text: 'Theme preference'),
        SizedBox(height: layout.sectionLabelGap),
        _ThemeOptionCard(
          title: 'System',
          subtitle: 'Match the device appearance.',
          icon: Icons.brightness_auto_rounded,
          isSelected: selectedTheme == 'SYSTEM',
          onTap: () => onThemeChanged('SYSTEM'),
        ),
        SizedBox(height: layout.themeOptionGap),
        _ThemeOptionCard(
          title: 'Light',
          subtitle: 'Use the lighter visual mode.',
          icon: Icons.light_mode_rounded,
          isSelected: selectedTheme == 'LIGHT',
          onTap: () => onThemeChanged('LIGHT'),
        ),
        SizedBox(height: layout.themeOptionGap),
        _ThemeOptionCard(
          title: 'Dark',
          subtitle: 'Use the darker visual mode.',
          icon: Icons.dark_mode_rounded,
          isSelected: selectedTheme == 'DARK',
          onTap: () => onThemeChanged('DARK'),
        ),
      ],
    );
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
