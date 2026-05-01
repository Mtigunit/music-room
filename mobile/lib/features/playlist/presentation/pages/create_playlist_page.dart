import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/app_back_button.dart';
import 'package:music_room/core/widgets/app_button.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/core/widgets/confirmation_dialog.dart';
import 'package:music_room/core/widgets/genre_selection_grid.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/events/presentation/widgets/selection_card.dart';
import 'package:music_room/features/playlist/data/datasources/playlist_remote_datasource.dart';
import 'package:music_room/features/playlist/domain/entities/playlist_entity.dart';
import 'package:music_room/features/playlist/domain/types/playlist_tags.dart';

class CreatePlaylistPage extends StatefulWidget {
  const CreatePlaylistPage({
    super.key,
    this.playlist,
    this.initialGenres = const <String>[],
  });

  final PlaylistDetailsEntity? playlist;
  final List<String> initialGenres;

  bool get isEditing => playlist != null;

  @override
  State<CreatePlaylistPage> createState() => _CreatePlaylistPageState();
}

class _CreatePlaylistPageState extends State<CreatePlaylistPage> {
  final IPlaylistRemoteDataSource _playlistDataSource =
      InjectionContainer().playlistRemoteDataSource;

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  late String? _selectedVisibility;
  late List<String> _selectedGenres;
  late bool _isEditAccessEnabled;
  String? _titleError;
  String? _privacyError;
  String? _genreError;
  bool _isSaving = false;
  bool _isDeleting = false;

  bool get _isPublicSelected => _selectedVisibility == 'PUBLIC';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.playlist?.name ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.playlist?.description ?? '',
    );
    _selectedVisibility = widget.playlist?.visibility;
    _selectedGenres = List<String>.from(
      widget.playlist?.tags ?? widget.initialGenres,
    );
    _isEditAccessEnabled =
        widget.playlist == null ||
        (widget.playlist!.visibility == 'PUBLIC' &&
            widget.playlist!.editLicense == 'OPEN');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _validateTitle(String value) {
    setState(() {
      _titleError = value.trim().isEmpty ? 'Playlist name is required' : null;
    });
  }

  bool _validateForm() {
    _validateTitle(_titleController.text);

    setState(() {
      _privacyError = _selectedVisibility == null
          ? 'Please choose Public or Private'
          : null;
      _genreError = widget.isEditing
          ? null
          : (_selectedGenres.isEmpty
                ? 'Please select at least one genre'
                : null);
    });

    return _titleError == null && _privacyError == null && _genreError == null;
  }

  Future<void> _savePlaylist() async {
    if (!_validateForm()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final request = CreatePlaylistRequest(
        name: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        visibility: _selectedVisibility!,
        editLicense: _selectedVisibility == 'PUBLIC' && _isEditAccessEnabled
            ? 'OPEN'
            : 'RESTRICTED',
        tags: _selectedGenres.isEmpty ? null : _selectedGenres,
      );

      if (widget.isEditing) {
        await _playlistDataSource.updatePlaylist(
          widget.playlist!.id,
          UpdatePlaylistRequest(
            name: request.name,
            description: request.description,
            visibility: request.visibility,
            editLicense: request.editLicense,
            tags: _selectedGenres,
          ),
        );
      } else {
        await _playlistDataSource.createPlaylist(request);
      }

      if (!mounted) {
        return;
      }

      AppSnackbar.showSuccess(
        context,
        widget.isEditing
            ? 'Playlist updated successfully.'
            : 'Playlist created successfully.',
      );
      Navigator.of(context).pop(true);
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }

      AppSnackbar.showError(context, _networkErrorMessage(error));
    } on Object {
      if (!mounted) {
        return;
      }

      AppSnackbar.showError(
        context,
        widget.isEditing
            ? 'Unable to update playlist right now.'
            : 'Unable to create playlist right now.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deletePlaylist() async {
    final playlist = widget.playlist;
    if (playlist == null || _isDeleting || !mounted) {
      return;
    }

    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'Delete playlist',
      message:
          'This action cannot be undone. '
          'The playlist and its tracks will be removed.',
      confirmLabel: 'Delete',
      icon: Icons.delete_forever_rounded,
      variant: ConfirmationDialogVariant.destructive,
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await _playlistDataSource.deletePlaylist(playlist.id);
      if (!mounted) {
        return;
      }

      AppSnackbar.showSuccess(context, 'Playlist deleted successfully.');
      Navigator.of(context).pop('deleted');
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }

      if (error.response?.statusCode == 403) {
        AppSnackbar.showError(
          context,
          'Only the owner can delete this playlist.',
        );
      } else {
        AppSnackbar.showError(context, 'Failed to delete playlist.');
      }
    } on Object {
      if (!mounted) {
        return;
      }
      AppSnackbar.showError(context, 'Failed to delete playlist.');
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  String _networkErrorMessage(DioException error) {
    if (error.response?.statusCode == 400) {
      return 'Please check your inputs and try again.';
    }

    if (error.response?.statusCode == 401) {
      return 'Please sign in again to create playlists.';
    }

    return 'Unable to create playlist right now.';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(widget.isEditing ? 'Playlist Settings' : 'Create Playlist'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel(text: 'PLAYLIST NAME'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  onChanged: _validateTitle,
                  decoration: _inputDecoration(
                    theme,
                    hintText: 'e.g. Late Night Vibes',
                  ).copyWith(errorText: _titleError),
                ),
                const SizedBox(height: 16),
                const _SectionLabel(text: 'DESCRIPTION (OPTIONAL)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: _inputDecoration(
                    theme,
                    hintText: "What's the vibe?",
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionLabel(text: 'PRIVACY'),
                const SizedBox(height: 10),
                SelectionCard(
                  title: 'Public',
                  subtitle: 'Anyone can discover and join your playlist',
                  icon: Icons.public,
                  isSelected: _selectedVisibility == 'PUBLIC',
                  onTap: () {
                    setState(() {
                      _selectedVisibility = 'PUBLIC';
                      _privacyError = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                SelectionCard(
                  title: 'Private',
                  subtitle: 'Only people with access can view it',
                  icon: Icons.lock_outline,
                  isSelected: _selectedVisibility == 'PRIVATE',
                  onTap: () {
                    setState(() {
                      _selectedVisibility = 'PRIVATE';
                      _isEditAccessEnabled = false;
                      _privacyError = null;
                    });
                  },
                ),
                if (_privacyError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _privacyError!,
                    style: TextStyle(
                      color: colorScheme.error,
                      fontSize: 13,
                    ),
                  ),
                ],
                if (_isPublicSelected) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.1,
                        ),
                      ),
                    ),
                    child: _buildToggleRow(
                      title: 'Edit Access',
                      subtitle: _isEditAccessEnabled
                          ? 'Users with the link can edit this playlist'
                          : 'Only owner/collaborators can edit this playlist',
                      value: _isEditAccessEnabled,
                      onChanged: (value) {
                        setState(() {
                          _isEditAccessEnabled = value;
                        });
                      },
                      theme: theme,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const _SectionLabel(text: 'GENRE'),
                const SizedBox(height: 10),
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
                  onGenreTapped: (displayLabel) {
                    final tag = PlaylistTag.all.firstWhere(
                      (item) => item.displayLabel == displayLabel,
                    );

                    setState(() {
                      if (_selectedGenres.contains(tag.value)) {
                        _selectedGenres.remove(tag.value);
                      } else {
                        _selectedGenres.add(tag.value);
                      }
                      _genreError = null;
                    });
                  },
                ),
                if (widget.isEditing)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Tap genres to update the playlist tags.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                if (_genreError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _genreError!,
                    style: TextStyle(
                      color: colorScheme.error,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: AppButton(
                    onPressed: _isSaving ? null : _savePlaylist,
                    label: widget.isEditing ? 'Save changes' : 'Save playlist',
                    isLoading: _isSaving,
                    borderRadius: 16,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (widget.isEditing) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: AppButton(
                      onPressed: _isDeleting ? null : _deletePlaylist,
                      label: 'Delete playlist',
                      isLoading: _isDeleting,
                      backgroundColor: colorScheme.error,
                      borderRadius: 16,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    ThemeData theme, {
    required String hintText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
      ),
      filled: true,
      fillColor: theme.colorScheme.surface,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.primary),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: theme.colorScheme.onPrimary,
          activeTrackColor: theme.colorScheme.primary,
          inactiveThumbColor: theme.colorScheme.onSurface.withValues(
            alpha: 0.5,
          ),
          inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        letterSpacing: 1.2,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    );
  }
}
