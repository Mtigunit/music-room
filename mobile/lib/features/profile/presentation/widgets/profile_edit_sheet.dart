import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/app_back_button.dart';
import 'package:music_room/core/widgets/app_button.dart';
import 'package:music_room/core/widgets/form_input_decoration.dart';
import 'package:music_room/core/widgets/form_section_label.dart';
import 'package:music_room/core/widgets/form_toggle_row.dart';
import 'package:music_room/core/widgets/genre_selection_grid.dart';
import 'package:music_room/features/events/presentation/widgets/selection_card.dart';
import 'package:music_room/features/playlist/domain/types/playlist_tags.dart';
import 'package:music_room/features/profile/domain/entities/profile_entity.dart';

class ProfileEditSheet extends StatefulWidget {
  const ProfileEditSheet({required this.profile, super.key});

  final UserProfileEntity profile;

  @override
  State<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<ProfileEditSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  late final TextEditingController _locationController;
  late final TextEditingController _dateOfBirthController;
  late final TextEditingController _physicalAddressController;
  late final TextEditingController _themeController;
  late final Set<String> _favoriteGenres;
  bool _autoAcceptInvites = false;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
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
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  MediaQuery.viewInsetsOf(context).bottom + 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FormSectionLabel(text: 'USERNAME'),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 20),
                    const FormSectionLabel(text: 'BIO'),
                    const SizedBox(height: 8),
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
                    const FormSectionLabel(text: 'LOCATION'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _locationController,
                      decoration: FormInputDecoration.build(
                        theme,
                        labelText: null,
                        hintText: 'City or region',
                      ),
                    ),
                    const SizedBox(height: 20),
                    const FormSectionLabel(text: 'DATE OF BIRTH'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _dateOfBirthController,
                      decoration: FormInputDecoration.build(
                        theme,
                        labelText: null,
                        hintText: 'YYYY-MM-DD',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_month_rounded),
                          onPressed: () => _pickDate(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const FormSectionLabel(text: 'PHYSICAL ADDRESS'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _physicalAddressController,
                      maxLines: 2,
                      decoration: FormInputDecoration.build(
                        theme,
                        labelText: null,
                        hintText: 'Optional address or venue area',
                      ),
                    ),
                    const SizedBox(height: 20),
                    FormToggleRow(
                      title: 'Auto accept invites',
                      subtitle: _autoAcceptInvites
                          ? 'Automatically accept room and playlist invitations'
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
                            (value) =>
                                PlaylistTag.fromValue(value)?.displayLabel,
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
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        onPressed: () {
                          final isValid =
                              _formKey.currentState?.validate() ?? false;
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
                              uiTheme: _themeController.text.isEmpty
                                  ? null
                                  : _themeController.text,
                            ),
                          );
                        },
                        label: 'Save changes',
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
    return value as bool? ?? false;
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
