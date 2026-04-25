import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:music_room/core/widgets/app_back_button.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/features/playlist/data/datasources/playlist_remote_datasource.dart';
import 'package:music_room/features/playlist/domain/entities/playlist_entity.dart';

class PlaylistSettingsPage extends StatefulWidget {
  const PlaylistSettingsPage({
    required this.playlist,
    required this.dataSource,
    super.key,
  });

  final PlaylistDetailsEntity playlist;
  final IPlaylistRemoteDataSource dataSource;

  @override
  State<PlaylistSettingsPage> createState() => _PlaylistSettingsPageState();
}

class _PlaylistSettingsPageState extends State<PlaylistSettingsPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  late bool _isPublicVisibility;
  late bool _isOpenEditAccess;
  bool _isSaving = false;

  bool get _hasChanges {
    final trimmedDescription = _descriptionController.text.trim();
    final initialDescription = widget.playlist.description?.trim() ?? '';

    return _nameController.text.trim() != widget.playlist.name.trim() ||
        trimmedDescription != initialDescription ||
        _isPublicVisibility != (widget.playlist.visibility == 'PUBLIC') ||
        _isOpenEditAccess !=
            (widget.playlist.visibility == 'PUBLIC' &&
                widget.playlist.editLicense == 'OPEN');
  }

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.playlist.name);
    _descriptionController = TextEditingController(
      text: widget.playlist.description ?? '',
    );

    _isPublicVisibility = widget.playlist.visibility == 'PUBLIC';
    _isOpenEditAccess =
        widget.playlist.visibility == 'PUBLIC' &&
        widget.playlist.editLicense == 'OPEN';

    _nameController.addListener(_onInputChanged);
    _descriptionController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_onInputChanged)
      ..dispose();
    _descriptionController
      ..removeListener(_onInputChanged)
      ..dispose();
    super.dispose();
  }

  void _onInputChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _saveSettings() async {
    final trimmedName = _nameController.text.trim();
    if (trimmedName.isEmpty) {
      AppSnackbar.showError(context, 'Playlist name is required.');
      return;
    }

    if (_isSaving || !_hasChanges) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final updatedVisibility = _isPublicVisibility ? 'PUBLIC' : 'PRIVATE';
    var updatedEditLicense = 'RESTRICTED';
    if (_isPublicVisibility && _isOpenEditAccess) {
      updatedEditLicense = 'OPEN';
    }

    final updatedDescription = _descriptionController.text.trim();

    try {
      await widget.dataSource.updatePlaylist(
        widget.playlist.id,
        UpdatePlaylistRequest(
          name: trimmedName,
          description: updatedDescription,
          visibility: updatedVisibility,
          editLicense: updatedEditLicense,
        ),
      );

      if (!mounted) {
        return;
      }

      AppSnackbar.showSuccess(context, 'Playlist settings updated.');
      Navigator.of(context).pop(
        PlaylistDetailsEntity(
          id: widget.playlist.id,
          name: trimmedName,
          ownerUserId: widget.playlist.ownerUserId,
          description: updatedDescription.isEmpty ? null : updatedDescription,
          visibility: updatedVisibility,
          editLicense: updatedEditLicense,
          tracks: widget.playlist.tracks,
          tags: widget.playlist.tags,
          updatedAt: widget.playlist.updatedAt,
        ),
      );
    } on DioException {
      if (!mounted) {
        return;
      }
      AppSnackbar.showError(context, 'Failed to save playlist settings.');
    } on Object {
      if (!mounted) {
        return;
      }
      AppSnackbar.showError(context, 'Failed to save playlist settings.');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final surfaceColor = theme.brightness == Brightness.dark
        ? colorScheme.surfaceContainerHigh
        : colorScheme.surfaceContainerLowest;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Playlist Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Text(
              'Update your playlist details and collaboration rules.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              style: TextStyle(color: colorScheme.onSurface),
              decoration: _fieldDecoration(
                context,
                fillColor: surfaceColor,
                hintText: 'Playlist name',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 5,
              maxLength: 255,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              inputFormatters: [LengthLimitingTextInputFormatter(255)],
              style: TextStyle(color: colorScheme.onSurface),
              decoration: _fieldDecoration(
                context,
                fillColor: surfaceColor,
                hintText: 'Description (optional)',
              ),
            ),
            const SizedBox(height: 18),
            _SettingsCard(
              title: 'Visibility',
              subtitle: _isPublicVisibility
                  ? 'Anyone can discover this playlist.'
                  : 'Only collaborators can access this playlist.',
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Public'),
                    icon: Icon(Icons.public),
                  ),
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Private'),
                    icon: Icon(Icons.lock_outline),
                  ),
                ],
                selected: <bool>{_isPublicVisibility},
                onSelectionChanged: (selection) {
                  setState(() {
                    _isPublicVisibility = selection.first;
                    if (!_isPublicVisibility) {
                      _isOpenEditAccess = false;
                    }
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            _SettingsCard(
              title: 'Edit Access',
              subtitle: _isPublicVisibility
                  ? (_isOpenEditAccess
                        ? 'Everyone can add songs.'
                        : 'Only invited collaborators can add songs.')
                  : 'Private playlists only allow invited collaborators.',
              child: Opacity(
                opacity: _isPublicVisibility ? 1 : 0.48,
                child: IgnorePointer(
                  ignoring: !_isPublicVisibility,
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('All Users'),
                        icon: Icon(Icons.group_outlined),
                      ),
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('Invited Only'),
                        icon: Icon(Icons.person_add_alt_1_outlined),
                      ),
                    ],
                    selected: <bool>{_isOpenEditAccess},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _isOpenEditAccess = selection.first;
                      });
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _isSaving || !_hasChanges ? null : _saveSettings,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required Color fillColor,
    required String hintText,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: colorScheme.onSurface.withValues(alpha: 0.55),
      ),
      filled: true,
      fillColor: fillColor,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.38),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.primary),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? colorScheme.surfaceContainer
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
