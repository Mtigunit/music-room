import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/form_input_decoration.dart';
import 'package:music_room/core/widgets/form_section_label.dart';
import 'package:music_room/core/widgets/genre_selection_grid.dart';
import 'package:music_room/core/widgets/responsive_layout.dart';
import 'package:music_room/features/auth/presentation/layouts/post_registration_profile_layout.dart';
import 'package:music_room/features/playlist/domain/types/playlist_tags.dart';

class ProfileFormSections extends StatelessWidget {
  const ProfileFormSections({
    required this.layout,
    required this.theme,
    required this.usernameController,
    required this.bioController,
    required this.locationController,
    required this.selectedGenres,
    required this.onGenreTapped,
    this.usernameValidator,
    super.key,
  });

  final ProfileLayout layout;
  final ThemeData theme;
  final TextEditingController usernameController;
  final TextEditingController bioController;
  final TextEditingController locationController;
  final Set<String> selectedGenres;
  final ValueChanged<String> onGenreTapped;
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
      ],
    );
  }

  Widget _buildExpandedContent() {
    return Column(
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
          onGenreTapped: _handleGenreTapped,
        ),
      ],
    );
  }

  void _handleGenreTapped(String displayLabel) {
    final tag = PlaylistTag.all.firstWhere(
      (value) => value.displayLabel == displayLabel,
      orElse: () => PlaylistTag.pop,
    );

    if (tag.displayLabel != displayLabel) {
      return;
    }

    onGenreTapped(tag.value);
  }
}
