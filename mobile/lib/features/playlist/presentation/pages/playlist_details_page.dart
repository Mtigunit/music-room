import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/core/widgets/empty_state_widget.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/auth/presentation/state/auth_state.dart';
import 'package:music_room/features/playlist/data/datasources/playlist_remote_datasource.dart';
import 'package:music_room/features/playlist/domain/entities/playlist_entity.dart';
import 'package:music_room/features/playlist/domain/types/playlist_tags.dart';
import 'package:music_room/features/playlist/presentation/pages/create_playlist_page.dart';
import 'package:music_room/features/playlist/presentation/state/playlist_bloc.dart';
import 'package:music_room/features/playlist/presentation/state/playlist_event.dart';
import 'package:music_room/features/playlist/presentation/state/playlist_state.dart';
import 'package:music_room/features/playlist/presentation/widgets/playlist_track_search_modal.dart';
import 'package:music_room/features/playlist/presentation/widgets/playlist_user_invite_bottom_sheet.dart';

class PlaylistDetailsPage extends StatefulWidget {
  const PlaylistDetailsPage({
    required this.playlistId,
    required this.playlistName,
    super.key,
  });

  final String playlistId;
  final String playlistName;

  @override
  State<PlaylistDetailsPage> createState() => _PlaylistDetailsPageState();
}

class _PlaylistDetailsPageState extends State<PlaylistDetailsPage>
    with SingleTickerProviderStateMixin {
  final IPlaylistRemoteDataSource _playlistDataSource =
      InjectionContainer().playlistRemoteDataSource;
  late final PlaylistBloc _playlistBloc;
  StreamSubscription<PlaylistState>? _playlistStateSubscription;
  final TextEditingController _searchController = TextEditingController();
  late final AnimationController _speedDialController;

  PlaylistDetailsEntity? _details;
  bool _isLoading = true;
  bool _isAddingTrack = false;
  bool _isOffline = false;
  bool _showStaleWarning = false;
  bool _isSyncing = false;
  bool _isReordering = false;
  bool _isSpeedDialOpen = false;
  Set<String> _removingTrackIds = <String>{};
  String? _errorMessage;

  String? get _currentUserId {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      return authState.user.id;
    }
    if (authState is LoginSuccess) {
      return authState.user.id;
    }
    if (authState is RegisterSuccess) {
      return authState.user.id;
    }
    if (authState is GoogleLoginSuccess) {
      return authState.user.id;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _speedDialController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 260,
      ),
      reverseDuration: const Duration(
        milliseconds: 200,
      ),
    );
    _playlistBloc = InjectionContainer().createPlaylistBloc();
    _playlistStateSubscription = _playlistBloc.stream.listen(
      _onPlaylistState,
    );
    _searchController.addListener(_onSearchChanged);
    _playlistBloc.add(
      PlaylistOpened(widget.playlistId),
    );
  }

  @override
  void dispose() {
    unawaited(_playlistStateSubscription?.cancel());
    unawaited(_playlistBloc.close());
    _speedDialController.dispose();
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onPlaylistState(PlaylistState state) {
    if (!mounted) {
      return;
    }

    final messageChanged =
        state.errorMessage != null &&
        state.errorMessage != _errorMessage &&
        state.status == PlaylistSyncStatus.ready;

    setState(() {
      _details = state.playlist;
      _isLoading =
          state.status == PlaylistSyncStatus.loading && state.playlist == null;
      _isOffline = state.isOffline;
      _showStaleWarning = state.showStaleWarning;
      _isSyncing = state.isSyncing;
      _isReordering = state.isReordering;
      _removingTrackIds = state.removingTrackIds.toSet();
      _errorMessage = state.status == PlaylistSyncStatus.error
          ? (state.errorMessage ?? 'Unable to load playlist details right now.')
          : null;
    });

    if (messageChanged) {
      AppSnackbar.showInfo(context, state.errorMessage!);
      _playlistBloc.add(const PlaylistSyncErrorCleared());
    }
  }

  Future<void> _toggleSpeedDial() async {
    if (_isSpeedDialOpen) {
      await _speedDialController.reverse();
      if (mounted) {
        setState(() {
          _isSpeedDialOpen = false;
        });
      }
      return;
    }

    setState(() {
      _isSpeedDialOpen = true;
    });
    await _speedDialController.forward();
  }

  Future<void> _closeSpeedDial() async {
    if (!_isSpeedDialOpen) {
      return;
    }
    await _speedDialController.reverse();
    if (mounted) {
      setState(() {
        _isSpeedDialOpen = false;
      });
    }
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _removeTrack(String playlistTrackId) {
    _playlistBloc.add(PlaylistRemoveTrackRequested(playlistTrackId));
  }

  Future<void> _openPlaylistSettings() async {
    final details = _details;
    if (details == null) {
      return;
    }

    if (!_isOwner(details)) {
      AppSnackbar.showInfo(
        context,
        'Only the playlist creator can edit permissions.',
      );
      return;
    }

    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        builder: (_) => CreatePlaylistPage(
          playlist: details,
          initialGenres: details.tags,
        ),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    if (result == 'deleted') {
      AppSnackbar.showSuccess(context, 'Playlist deleted.');
      Navigator.of(context).pop();
      return;
    }

    if (result != true) {
      return;
    }

    _playlistBloc.add(const PlaylistRefreshRequested());
  }

  Future<void> _openInviteUsersSheet() async {
    final details = _details;
    if (details == null || !_isOwner(details)) {
      AppSnackbar.showInfo(
        context,
        'Only the playlist creator can invite users.',
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PlaylistUserInviteBottomSheet(
        playlistId: widget.playlistId,
        playlistName: widget.playlistName,
      ),
    );
  }

  Future<void> _loadPlaylistDetails() async {
    _playlistBloc.add(const PlaylistRefreshRequested());
  }

  bool _isOwner(PlaylistDetailsEntity details) {
    final currentUserId = _currentUserId;
    return currentUserId != null && details.ownerUserId == currentUserId;
  }

  bool _isCollaborator(PlaylistDetailsEntity details) {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      return false;
    }

    return details.collaboratorIds.contains(currentUserId);
  }

  bool _canEditTracks(PlaylistDetailsEntity details) {
    final publicEditEnabled =
        details.visibility == 'PUBLIC' && details.editLicense == 'OPEN';
    return publicEditEnabled || _isOwner(details) || _isCollaborator(details);
  }

  bool _canManageCollaborators(PlaylistDetailsEntity details) {
    return _isOwner(details);
  }

  List<PlaylistTrackEntity> get _visibleTracks {
    final details = _details;
    if (details == null) {
      return const <PlaylistTrackEntity>[];
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return details.tracks;
    }

    return details.tracks
        .where((track) {
          final searchable = '${track.title} ${track.artist ?? ''}'
              .toLowerCase();
          return searchable.contains(query);
        })
        .toList(growable: false);
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (_isReordering) {
      return;
    }

    if (_searchController.text.trim().isNotEmpty) {
      AppSnackbar.showInfo(
        context,
        'Clear search to reorder the full playlist.',
      );
      return;
    }
    _playlistBloc.add(
      PlaylistReorderRequested(oldIndex: oldIndex, newIndex: newIndex),
    );
  }

  Future<void> _openAddSongs() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) {
        return PlaylistTrackSearchModal(
          dataSource: _playlistDataSource,
          onAddTrack: _addTrack,
        );
      },
    );
  }

  Future<bool> _addTrack(TrackSearchEntity track) async {
    setState(() {
      _isAddingTrack = true;
    });

    try {
      _playlistBloc.add(PlaylistAddTrackRequested(track));
      if (mounted) {
        AppSnackbar.showSuccess(context, 'Song added to playlist.');
      }
      return true;
    } on DioException {
      if (!mounted) {
        return false;
      }
      AppSnackbar.showError(context, 'Failed to add song to playlist.');
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isAddingTrack = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pageBackground = theme.scaffoldBackgroundColor;
    final details = _details;
    final canEditTracks = details != null && _canEditTracks(details);
    final canManageCollaborators =
        details != null && _canManageCollaborators(details);
    final canManageEditPermissions = details != null && _isOwner(details);

    return Scaffold(
      backgroundColor: pageBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        forceMaterialTransparency: true,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
            ),
            style: IconButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurface,
              backgroundColor: theme.colorScheme.surface,
              padding: EdgeInsets.zero,
              minimumSize: const Size(40, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: const CircleBorder(),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? _ErrorState(
                message: _errorMessage!,
                onRetry: () {
                  unawaited(_loadPlaylistDetails());
                },
              )
            : _buildContent(context),
      ),
      floatingActionButton:
          (details != null &&
              (canEditTracks ||
                  canManageCollaborators ||
                  canManageEditPermissions))
          ? _PlaylistSpeedDial(
              animation: _speedDialController,
              isOpen: _isSpeedDialOpen,
              isAddingTrack: _isAddingTrack || _isOffline || _isReordering,
              canAddSongs: canEditTracks,
              canInviteUsers: canManageCollaborators,
              canOpenSettings: canManageEditPermissions,
              onToggle: _toggleSpeedDial,
              onAddSongs: () async {
                if (!canEditTracks) {
                  AppSnackbar.showInfo(
                    context,
                    'You do not have permission to edit this playlist.',
                  );
                  return;
                }
                if (_isOffline) {
                  AppSnackbar.showInfo(
                    context,
                    'You are offline. Playlist is read-only.',
                  );
                  return;
                }
                await _closeSpeedDial();
                unawaited(_openAddSongs());
              },
              onInviteUsers: () async {
                if (!canManageCollaborators) {
                  AppSnackbar.showInfo(
                    context,
                    'Only the playlist creator can invite users.',
                  );
                  return;
                }
                await _closeSpeedDial();
                unawaited(_openInviteUsersSheet());
              },
              onOpenSettings: () async {
                if (!canManageEditPermissions) {
                  AppSnackbar.showInfo(
                    context,
                    'Only the playlist creator can edit permissions.',
                  );
                  return;
                }
                await _closeSpeedDial();
                unawaited(_openPlaylistSettings());
              },
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildContent(BuildContext context) {
    final details = _details;
    if (details == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textMuted = colorScheme.onSurface.withValues(alpha: 0.62);
    final cardColor = colorScheme.surfaceContainer;
    final borderColor = colorScheme.outline.withValues(alpha: 0.24);
    final tracks = _visibleTracks;
    final description = details.description?.trim();
    final hasDescription = description != null && description.isNotEmpty;
    final parsedTags = details.tags
        .map(PlaylistTag.fromValue)
        .whereType<PlaylistTag>() // removes nulls (invalid tags)
        .toList(growable: false);

    final tags = parsedTags.isEmpty ? <PlaylistTag>[] : parsedTags;
    final artworkUrl = _playlistArtworkUrl(details);
    final safeAreaTop = MediaQuery.paddingOf(context).top;
    final heroHeight = (MediaQuery.sizeOf(context).width * 0.56).clamp(
      180.0,
      250.0,
    );
    final canEditTracks = _canEditTracks(details);
    final isInteractionLocked = _isOffline || _isReordering || !canEditTracks;

    return Stack(
      children: [
        Column(
          children: [
            if (_isOffline)
              _SyncBanner(
                text: 'You are offline. Playlist is read-only.',
                background: colorScheme.errorContainer,
                foreground: colorScheme.onErrorContainer,
              ),
            if (_showStaleWarning)
              _SyncBanner(
                text: 'This playlist may be outdated',
                background: colorScheme.tertiaryContainer,
                foreground: colorScheme.onTertiaryContainer,
              ),
            if (_isSyncing || _isReordering)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: AbsorbPointer(
                absorbing: isInteractionLocked,
                child: RefreshIndicator(
                  onRefresh: _loadPlaylistDetails,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            _PlaylistHeroImage(
                              imageUrl: artworkUrl,
                              height: heroHeight + safeAreaTop,
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                16,
                                20,
                                16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    details.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.displaySmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          height: 1.08,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${details.tracks.length} tracks • '
                                    '${_formatPlaylistDuration(
                                      details.tracks,
                                    )}',
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: textMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: tags
                                        .map(
                                          (tag) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colorScheme.primary
                                                  .withValues(
                                                    alpha: 0.1,
                                                  ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    20,
                                                  ),
                                            ),
                                            child: Text(
                                              tag.displayLabel,
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color: colorScheme.primary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
                                  ),
                                  if (hasDescription) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      description,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            color: colorScheme.onSurface
                                                .withValues(
                                                  alpha: 0.78,
                                                ),
                                            height: 1.35,
                                          ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _searchController,
                                    textInputAction: TextInputAction.search,
                                    style: theme.textTheme.bodyLarge,
                                    decoration: InputDecoration(
                                      hintText: 'Search songs in playlist...',
                                      hintStyle: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            color: textMuted,
                                          ),
                                      prefixIcon: Icon(
                                        Icons.search,
                                        color: textMuted,
                                      ),
                                      suffixIcon:
                                          _searchController.text
                                              .trim()
                                              .isNotEmpty
                                          ? IconButton(
                                              onPressed:
                                                  _searchController.clear,
                                              icon: Icon(
                                                Icons.close,
                                                color: textMuted,
                                              ),
                                            )
                                          : null,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 18,
                                          ),
                                      filled: true,
                                      fillColor: colorScheme
                                          .surfaceContainerHighest
                                          .withValues(
                                            alpha: 0.65,
                                          ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(22),
                                        borderSide: BorderSide(
                                          color: borderColor,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(22),
                                        borderSide: BorderSide(
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (tracks.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyTracksState(
                            query: _searchController.text.trim(),
                            onAddSong: _openAddSongs,
                            canAddSong: canEditTracks,
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                          sliver: SliverToBoxAdapter(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Tracks',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        height: 1.05,
                                      ),
                                ),
                                Text(
                                  _isOffline
                                      ? 'Read-only'
                                      : (!canEditTracks
                                            ? 'View-only'
                                            : (_isReordering
                                                  ? 'Updating order...'
                                                  : 'Drag to reorder')),
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (tracks.isEmpty)
                        const SliverToBoxAdapter(child: SizedBox.shrink())
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          sliver: SliverReorderableList(
                            itemCount: tracks.length,
                            onReorder: isInteractionLocked
                                ? (_, _) {
                                    AppSnackbar.showInfo(
                                      context,
                                      _isOffline
                                          ? 'You are offline. '
                                                'Playlist is read-only.'
                                          : 'Please wait until '
                                                'reordering completes.',
                                    );
                                  }
                                : _onReorder,
                            itemBuilder: (context, index) {
                              final track = tracks[index];
                              final canRemove = canEditTracks;
                              final isRemoving = _removingTrackIds.contains(
                                track.playlistTrackId,
                              );
                              return Padding(
                                key: ValueKey<String>(track.playlistTrackId),
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _PlaylistTrackTile(
                                  dragIndex: index,
                                  track: track,
                                  formatDuration: _formatDuration,
                                  cardColor: cardColor,
                                  borderColor: borderColor,
                                  mutedTextColor: textMuted,
                                  iconColor: colorScheme.primary,
                                  canRemove: canRemove,
                                  showDragHandle: canEditTracks,
                                  isRemoving: isRemoving,
                                  onRemove: () {
                                    if (!canRemove || isRemoving) {
                                      return;
                                    }
                                    if (_isOffline ||
                                        _isReordering ||
                                        !canEditTracks) {
                                      final msg = _isOffline
                                          ? 'You are offline. '
                                                'Playlist is read-only.'
                                          : !canEditTracks
                                          ? "You don't have "
                                                'permission to edit this.'
                                          : 'Please wait until '
                                                'reordering completes.';
                                      AppSnackbar.showInfo(context, msg);
                                    }
                                    _removeTrack(track.playlistTrackId);
                                  },
                                  onTap: () {
                                    final detailsMessage =
                                        '${track.title} • '
                                        '${track.artist ?? 'Unknown artist'} • '
                                        '${_formatDuration(track.durationMs)}';
                                    AppSnackbar.showInfo(
                                      context,
                                      detailsMessage,
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_isReordering)
          Positioned.fill(
            child: ColoredBox(
              color: colorScheme.surface.withValues(alpha: 0.45),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: borderColor,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 22,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Updating track order...',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatDuration(int durationMs) {
    final totalSeconds = (durationMs / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatPlaylistDuration(List<PlaylistTrackEntity> tracks) {
    final totalDurationMs = tracks.fold<int>(
      0,
      (sum, track) => sum + track.durationMs,
    );
    final totalSeconds = (totalDurationMs / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String? _playlistArtworkUrl(PlaylistDetailsEntity details) {
    for (final track in details.tracks) {
      final thumbnailUrl = track.thumbnailUrl;
      if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
        return thumbnailUrl;
      }
    }
    return null;
  }
}

class _PlaylistSpeedDial extends StatelessWidget {
  const _PlaylistSpeedDial({
    required this.animation,
    required this.isOpen,
    required this.isAddingTrack,
    required this.canAddSongs,
    required this.canInviteUsers,
    required this.canOpenSettings,
    required this.onToggle,
    required this.onAddSongs,
    required this.onInviteUsers,
    required this.onOpenSettings,
  });

  final Animation<double> animation;
  final bool isOpen;
  final bool isAddingTrack;
  final bool canAddSongs;
  final bool canInviteUsers;
  final bool canOpenSettings;
  final Future<void> Function() onToggle;
  final VoidCallback onAddSongs;
  final VoidCallback onInviteUsers;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const double actionIconDiameter = 56;
    const double actionColumnWidth = 450;
    final hasOnlyAddAction = canAddSongs && !canInviteUsers && !canOpenSettings;
    final showListMenuIcon = canAddSongs && canInviteUsers;
    final fadeCurve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!hasOnlyAddAction)
          SizeTransition(
            sizeFactor: fadeCurve,
            axisAlignment: -1,
            child: FadeTransition(
              opacity: fadeCurve,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (canAddSongs) ...[
                    _SpeedDialActionRow(
                      animation: CurvedAnimation(
                        parent: animation,
                        curve: const Interval(
                          0,
                          0.72,
                          curve: Curves.easeOutCubic,
                        ),
                        reverseCurve: const Interval(
                          0,
                          0.65,
                          curve: Curves.easeInCubic,
                        ),
                      ),
                      icon: Icons.music_note_rounded,
                      label: isAddingTrack ? 'Adding...' : 'Add Songs',
                      onPressed: isAddingTrack ? null : onAddSongs,
                      rowWidth: actionColumnWidth,
                      iconDiameter: actionIconDiameter,
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (canInviteUsers) ...[
                    _SpeedDialActionRow(
                      animation: CurvedAnimation(
                        parent: animation,
                        curve: const Interval(
                          0.1,
                          0.84,
                          curve: Curves.easeOutCubic,
                        ),
                        reverseCurve: const Interval(
                          0,
                          0.75,
                          curve: Curves.easeInCubic,
                        ),
                      ),
                      icon: Icons.person_add_alt_1_rounded,
                      label: 'Invite Users to Playlist',
                      onPressed: onInviteUsers,
                      rowWidth: actionColumnWidth,
                      iconDiameter: actionIconDiameter,
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (canOpenSettings) ...[
                    _SpeedDialActionRow(
                      animation: CurvedAnimation(
                        parent: animation,
                        curve: const Interval(
                          0.18,
                          1,
                          curve: Curves.easeOutCubic,
                        ),
                        reverseCurve: const Interval(
                          0,
                          0.88,
                          curve: Curves.easeInCubic,
                        ),
                      ),
                      icon: Icons.tune_rounded,
                      label: 'Playlist Settings',
                      onPressed: onOpenSettings,
                      rowWidth: actionColumnWidth,
                      iconDiameter: actionIconDiameter,
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),
        SizedBox(
          width: actionColumnWidth,
          child: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: actionIconDiameter,
              height: actionIconDiameter,
              child: FloatingActionButton(
                onPressed: hasOnlyAddAction
                    ? (isAddingTrack ? null : onAddSongs)
                    : () {
                        unawaited(onToggle());
                      },
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 10,
                child: hasOnlyAddAction
                    ? (isAddingTrack
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.onPrimary,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.add_rounded,
                              size: 28,
                            ))
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, anim) {
                          return RotationTransition(
                            turns: Tween<double>(
                              begin: 0.85,
                              end: 1,
                            ).animate(anim),
                            child: FadeTransition(opacity: anim, child: child),
                          );
                        },
                        child: Icon(
                          isOpen
                              ? Icons.close_rounded
                              : (showListMenuIcon
                                    ? Icons.menu_rounded
                                    : Icons.add_rounded),
                          key: ValueKey<bool>(isOpen),
                          size: 28,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpeedDialActionRow extends StatelessWidget {
  const _SpeedDialActionRow({
    required this.animation,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.rowWidth,
    required this.iconDiameter,
  });

  final Animation<double> animation;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final double rowWidth;
  final double iconDiameter;

  static const double _radius = 15;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDisabled = onPressed == null;

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.12, 0),
          end: Offset.zero,
        ).animate(animation),
        child: SizedBox(
          width: rowWidth,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // LABEL
              Container(
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(
                    alpha: isDisabled ? 0.5 : 0.95,
                  ),
                  borderRadius: BorderRadius.circular(_radius),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.2),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // ICON BUTTON (no more circle)
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(_radius),
                child: InkWell(
                  onTap: onPressed,
                  borderRadius: BorderRadius.circular(_radius),
                  child: Ink(
                    width: iconDiameter,
                    height: iconDiameter,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(_radius),
                      border: Border.all(
                        color: colorScheme.primary.withValues(
                          alpha: isDisabled ? 0.4 : 1,
                        ),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: colorScheme.primary.withValues(
                        alpha: isDisabled ? 0.4 : 1,
                      ),
                      size: 30,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistHeroImage extends StatelessWidget {
  const _PlaylistHeroImage({
    required this.height,
    required this.imageUrl,
  });

  final double height;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: colorScheme.surfaceContainer,
            child: hasImage
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Center(
                      child: Icon(
                        Icons.queue_music_rounded,
                        size: 64,
                        color: colorScheme.primary,
                      ),
                    ),
                  )
                : Center(
                    child: Icon(
                      Icons.queue_music_rounded,
                      size: 64,
                      color: colorScheme.primary,
                    ),
                  ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: height * 0.38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.surface.withValues(alpha: 0),
                    colorScheme.surface.withValues(alpha: 0.24),
                    colorScheme.surface,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistTrackTile extends StatelessWidget {
  const _PlaylistTrackTile({
    required this.dragIndex,
    required this.track,
    required this.formatDuration,
    required this.cardColor,
    required this.borderColor,
    required this.mutedTextColor,
    required this.iconColor,
    required this.canRemove,
    required this.isRemoving,
    required this.showDragHandle,
    required this.onRemove,
    required this.onTap,
  });

  final int dragIndex;
  final PlaylistTrackEntity track;
  final String Function(int durationMs) formatDuration;
  final Color cardColor;
  final Color borderColor;
  final Color mutedTextColor;
  final Color iconColor;
  final bool canRemove;
  final bool isRemoving;
  final bool showDragHandle;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasThumbnail =
        track.thumbnailUrl != null && track.thumbnailUrl!.isNotEmpty;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: borderColor.withValues(alpha: 0.9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                if (showDragHandle) ...[
                  ReorderableDelayedDragStartListener(
                    index: dragIndex,
                    child: Icon(
                      Icons.drag_indicator,
                      color: mutedTextColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 58,
                    height: 58,
                    child: hasThumbnail
                        ? Image.network(
                            track.thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.music_note_rounded,
                              color: iconColor,
                            ),
                          )
                        : Icon(Icons.music_note_rounded, color: iconColor),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        track.artist ?? 'Unknown artist',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: mutedTextColor,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatDuration(track.durationMs),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: mutedTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (canRemove) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: isRemoving ? null : onRemove,
                        borderRadius: BorderRadius.circular(20),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: Center(
                            child: isRemoving
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: mutedTextColor,
                                    ),
                                  )
                                : Icon(
                                    Icons.close_rounded,
                                    color: mutedTextColor,
                                    size: 22,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: background,
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyTracksState extends StatelessWidget {
  const _EmptyTracksState({
    required this.query,
    required this.onAddSong,
    required this.canAddSong,
  });

  final String query;
  final VoidCallback onAddSong;
  final bool canAddSong;

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.isNotEmpty;

    return EmptyStateWidget(
      icon: Icons.library_music_outlined,
      message: hasQuery
          ? 'No songs match "$query".\nTry another search term.'
          : canAddSong
          ? 'This playlist is empty.\nAdd tracks to get started.'
          : 'This playlist is empty.\n'
                'You can only view tracks once the creator '
                'adds them.',
      actionLabel: hasQuery || !canAddSong ? null : 'Add Songs',
      onActionPressed: hasQuery || !canAddSong ? null : onAddSong,
    );
  }
}
