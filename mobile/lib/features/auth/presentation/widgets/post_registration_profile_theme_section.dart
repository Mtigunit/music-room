import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/form_section_label.dart';
import 'package:music_room/features/auth/presentation/layouts/post_registration_profile_layout.dart';
import 'package:music_room/features/events/presentation/widgets/selection_card.dart';

class PostRegistrationProfileThemeSection extends StatelessWidget {
  const PostRegistrationProfileThemeSection({
    required this.layout,
    required this.theme,
    required this.selectedTheme,
    required this.onThemeChanged,
    super.key,
  });

  final ProfileLayout layout;
  final ThemeData theme;
  final String selectedTheme;
  final ValueChanged<String> onThemeChanged;

  @override
  Widget build(BuildContext context) {
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
