import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room/core/theme/app_theme.dart';
import 'package:music_room/core/utils/tag_genre_normalizer.dart';
import 'package:music_room/core/widgets/app_back_button.dart';
import 'package:music_room/core/widgets/app_brand_icon.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/core/widgets/empty_state_widget.dart';
import 'package:music_room/core/widgets/responsive_layout.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/auth/presentation/state/auth_state.dart';
import 'package:music_room/features/playlist/data/datasources/playlist_remote_datasource.dart';
import 'package:music_room/features/playlist/domain/entities/playlist_entity.dart';
import 'package:music_room/features/playlist/presentation/pages/create_playlist_page.dart';
import 'package:music_room/features/playlist/presentation/state/playlist_bloc.dart';
import 'package:music_room/features/playlist/presentation/state/playlist_event.dart';
import 'package:music_room/features/playlist/presentation/state/playlist_state.dart';
import 'package:music_room/features/playlist/presentation/widgets/playlist_track_search_modal.dart';
import 'package:music_room/features/playlist/presentation/widgets/playlist_user_invite_bottom_sheet.dart';
import 'package:music_room/features/playlist/presentation/widgets/skeletons/playlist_details_skeleton.dart';

// ---------------------------------------------------------------------------
// Design tokens — single source of truth for the dark aesthetic
// ---------------------------------------------------------------------------

abstract final class _Token {
  // Surfaces — derive from theme tokens in AppTheme where possible
  static Color pageBg(BuildContext context) =>
      Theme.of(context).colorScheme.brightness == Brightness.dark
      ? AppTheme.playlistPageBg
      : Theme.of(context).colorScheme.surface;

  static Color heroGradientTop(BuildContext context) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    return isDark
        ? AppTheme.playlistHeroTop
        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.04);
  }

  static Color heroGradientMid(BuildContext context) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    return isDark
        ? AppTheme.playlistHeroMid
        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.02);
  }

  static Color cardBg(BuildContext context) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    return isDark
        ? AppTheme.playlistCardBg
        : Theme.of(context).colorScheme.surface.withValues(alpha: 0.04);
  }

  static Color cardBgHover(BuildContext context) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    return isDark
        ? AppTheme.playlistCardBgHover
        : Theme.of(context).colorScheme.surface.withValues(alpha: 0.06);
  }

  // cardBgActive: not used directly by page components

  // Borders
  static Color borderSubtle(BuildContext context) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    return isDark
        ? AppTheme.playlistBorderSubtle
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2);
  }

  // borderCard / borderPurple: theme-aware borders are provided via borderSubtle

  // Brand
  static Color purple(BuildContext context) => AppTheme.playlistPurple;
  static Color purpleLight(BuildContext context) =>
      AppTheme.playlistPurpleLight;

  // Text
  static Color textPrimary(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Theme.of(context).textTheme.displaySmall?.color ?? scheme.onSurface;
  }

  static Color textSecondary(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Theme.of(context).textTheme.bodyLarge?.color ??
        scheme.onSurface.withValues(alpha: 0.72);
  }

  static Color textMuted(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Theme.of(
          context,
        ).textTheme.bodyLarge?.color?.withValues(alpha: 0.6) ??
        scheme.onSurface.withValues(alpha: 0.6);
  }

  // Artwork gradient cells
  static List<List<Color>> artworkGradients(BuildContext context) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    if (isDark) return AppTheme.playlistArtworkGradients;
    return AppTheme.playlistArtworkGradients
        .map(
          (pair) => [
            pair[0].withValues(alpha: 0.14),
            pair[1].withValues(alpha: 0.10),
          ],
        )
        .toList(growable: false);
  }

  // Radii
  static const double radiusCard = 12;
  static const double radiusArtwork = 16;
  static const double radiusPill = 999;
  static const double radiusTag = 20;
  static const double radiusSearch = 10;

  // Spacing
  static const double heroPadH = 32;
}

// ---------------------------------------------------------------------------
// Layout constants
// ---------------------------------------------------------------------------

class _Layout {
  const _Layout(this.screenSize);

  final ScreenSize screenSize;

  bool get isCompact => screenSize == ScreenSize.compact;
  bool get isWide => !isCompact;

  double get horizontalPadding => switch (screenSize) {
    ScreenSize.compact => 16,
    ScreenSize.medium => 24,
    _ => _Token.heroPadH,
  };

  double get contentMaxWidth => switch (screenSize) {
    ScreenSize.compact => double.infinity,
    ScreenSize.medium => 1120,
    _ => 1280,
  };

  double get heroImageSize => switch (screenSize) {
    ScreenSize.compact => double.infinity,
    ScreenSize.medium => 160,
    _ => 172,
  };

  double get heroImageHeight => switch (screenSize) {
    ScreenSize.compact => 220,
    ScreenSize.medium => 160,
    _ => 172,
  };

  double get titleFontSize => switch (screenSize) {
    ScreenSize.compact => 36,
    ScreenSize.medium => 40,
    _ => 42,
  };

  String get trackSectionTitle =>
      isCompact ? 'Tracks' : 'Playlist organization';

  bool get showTrackColumnHeader => !isCompact;
  bool get showInlineHeroActions => !isCompact;
}

// ---------------------------------------------------------------------------
// Duration helpers
// ---------------------------------------------------------------------------

String _formatDurationMs(int durationMs) {
  final total = (durationMs / 1000).round();
  final m = total ~/ 60;
  final s = total % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

String _formatTotalDuration(List<PlaylistTrackEntity> tracks) {
  final total = tracks.fold<int>(0, (sum, t) => sum + t.durationMs);
  final totalSeconds = (total / 1000).round();
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// Auth helper
// ---------------------------------------------------------------------------

String? _resolveUserId(BuildContext context) {
  return switch (context.read<AuthBloc>().state) {
    AuthAuthenticated(:final user) => user.id,
    LoginSuccess(:final user) => user.id,
    RegisterSuccess(:final user) => user.id,
    GoogleLoginSuccess(:final user) => user.id,
    _ => null,
  };
}

// ---------------------------------------------------------------------------
// Permission model
// ---------------------------------------------------------------------------

class _Permissions {
  const _Permissions._({
    required this.canEditTracks,
    required this.canManageCollaborators,
    required this.canManageSettings,
    required this.userId,
    required this.isOwner,
    required this.collaboratorCount,
  });

  factory _Permissions.of(PlaylistDetailsEntity? details, String? userId) {
    if (details == null) {
      return const _Permissions._(
        canEditTracks: false,
        canManageCollaborators: false,
        canManageSettings: false,
        userId: null,
        isOwner: false,
        collaboratorCount: 0,
      );
    }
    final isOwner = userId != null && details.ownerUserId == userId;
    final isCollaborator =
        userId != null && details.collaboratorIds.contains(userId);
    final isPublicOpen =
        details.visibility == 'PUBLIC' && details.editLicense == 'OPEN';
    return _Permissions._(
      canEditTracks: isPublicOpen || isOwner || isCollaborator,
      canManageCollaborators: isOwner,
      canManageSettings: isOwner,
      userId: userId,
      isOwner: isOwner,
      collaboratorCount: details.collaboratorCount,
    );
  }

  final bool canEditTracks;
  final bool canManageCollaborators;
  final bool canManageSettings;
  final String? userId;
  final bool isOwner;
  final int collaboratorCount;

  bool get canInvite =>
      canManageCollaborators &&
      collaboratorCount < PlaylistDetailsEntity.maxCollaborators;

  bool canRemoveTrack(PlaylistTrackEntity track) {
    return isOwner || (userId != null && track.addedByUserId == userId);
  }
}

// ---------------------------------------------------------------------------
// Page state model
// ---------------------------------------------------------------------------

class _PageState {
  const _PageState({
    this.details,
    this.isLoading = true,
    this.isAddingTrack = false,
    this.isOffline = false,
    this.showStaleWarning = false,
    this.isSyncing = false,
    this.isReordering = false,
    this.removingTrackIds = const {},
    this.errorMessage,
    this.wasReordering = false,
    this.previousRemovingTrackIds = const {},
  });

  final PlaylistDetailsEntity? details;
  final bool isLoading;
  final bool isAddingTrack;
  final bool isOffline;
  final bool showStaleWarning;
  final bool isSyncing;
  final bool isReordering;
  final Set<String> removingTrackIds;
  final String? errorMessage;
  final bool wasReordering;
  final Set<String> previousRemovingTrackIds;

  bool get isInteractionLocked => isOffline || isReordering;

  _PageState copyWith({
    PlaylistDetailsEntity? details,
    bool? isLoading,
    bool? isAddingTrack,
    bool? isOffline,
    bool? showStaleWarning,
    bool? isSyncing,
    bool? isReordering,
    Set<String>? removingTrackIds,
    String? errorMessage,
    bool clearError = false,
    bool? wasReordering,
    Set<String>? previousRemovingTrackIds,
  }) => _PageState(
    details: details ?? this.details,
    isLoading: isLoading ?? this.isLoading,
    isAddingTrack: isAddingTrack ?? this.isAddingTrack,
    isOffline: isOffline ?? this.isOffline,
    showStaleWarning: showStaleWarning ?? this.showStaleWarning,
    isSyncing: isSyncing ?? this.isSyncing,
    isReordering: isReordering ?? this.isReordering,
    removingTrackIds: removingTrackIds ?? this.removingTrackIds,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    wasReordering: wasReordering ?? this.wasReordering,
    previousRemovingTrackIds:
        previousRemovingTrackIds ?? this.previousRemovingTrackIds,
  );
}

// ---------------------------------------------------------------------------
// PlaylistDetailsPage
// ---------------------------------------------------------------------------

class PlaylistDetailsPage extends StatefulWidget {
  const PlaylistDetailsPage({
    required this.playlistId,
    super.key,
  });

  final String playlistId;

  @override
  State<PlaylistDetailsPage> createState() => _PlaylistDetailsPageState();
}

class _PlaylistDetailsPageState extends State<PlaylistDetailsPage> {
  final IPlaylistRemoteDataSource _dataSource =
      InjectionContainer().playlistRemoteDataSource;

  late final PlaylistBloc _bloc;
  StreamSubscription<PlaylistState>? _blocSub;
  final TextEditingController _searchController = TextEditingController();

  _PageState _state = const _PageState();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _bloc = InjectionContainer().createPlaylistBloc();
    _blocSub = _bloc.stream.listen(_onBlocState);
    _searchController.addListener(_onSearchChanged);
    _bloc.add(PlaylistOpened(widget.playlistId));
  }

  @override
  void dispose() {
    unawaited(_blocSub?.cancel());
    unawaited(_bloc.close());
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  // ── State handling ────────────────────────────────────────────────────────

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  void _onBlocState(PlaylistState next) {
    if (!mounted) return;

    final prev = _state;

    final reorderCompleted =
        prev.wasReordering && !next.isReordering && next.errorMessage == null;
    final removedIds = prev.previousRemovingTrackIds.difference(
      next.removingTrackIds.toSet(),
    );
    final trackRemoved = removedIds.isNotEmpty && next.errorMessage == null;
    final hasNewError =
        next.errorMessage != null &&
        next.errorMessage != prev.errorMessage &&
        next.status == PlaylistSyncStatus.ready;

    setState(() {
      _state = _state.copyWith(
        details: next.playlist,
        isLoading:
            next.status == PlaylistSyncStatus.loading && next.playlist == null,
        isOffline: next.isOffline,
        showStaleWarning: next.showStaleWarning,
        isSyncing: next.isSyncing,
        isReordering: next.isReordering,
        removingTrackIds: next.removingTrackIds.toSet(),
        errorMessage: next.status == PlaylistSyncStatus.error
            ? (next.errorMessage ?? 'Unable to load playlist details.')
            : null,
        clearError: next.status != PlaylistSyncStatus.error,
        wasReordering: next.isReordering,
        previousRemovingTrackIds: next.removingTrackIds.toSet(),
      );
    });

    if (hasNewError) {
      AppSnackbar.showError(context, next.errorMessage!);
      _bloc.add(const PlaylistSyncErrorCleared());
    }
    if (reorderCompleted) {
      AppSnackbar.showSuccess(context, 'Playlist order updated.');
    }
    if (trackRemoved) {
      final word = removedIds.length == 1 ? 'track' : 'tracks';
      AppSnackbar.showSuccess(context, 'Removed ${removedIds.length} $word.');
    }
  }

  // ── Permissions ────────────────────────────────────────────────────────────

  _Permissions get _permissions =>
      _Permissions.of(_state.details, _resolveUserId(context));

  // ── Track helpers ─────────────────────────────────────────────────────────

  List<PlaylistTrackEntity> get _visibleTracks {
    final tracks = _state.details?.tracks ?? const <PlaylistTrackEntity>[];
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return tracks;
    return tracks
        .where(
          (t) => '${t.title} ${t.artist ?? ''}'.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  String? get _artworkUrl {
    for (final t in _state.details?.tracks ?? const <PlaylistTrackEntity>[]) {
      if (t.thumbnailUrl?.isNotEmpty == true) return t.thumbnailUrl;
    }
    return null;
  }

  // ── Guards ────────────────────────────────────────────────────────────────

  bool _guard({required bool condition, required String message}) {
    if (condition) {
      AppSnackbar.showError(context, message);
      return false;
    }
    return true;
  }

  bool get _isOfflineBlocked => !_guard(
    condition: _state.isOffline,
    message: 'You are offline. Playlist is read-only.',
  );

  // ── Actions ───────────────────────────────────────────────────────────────

  void _removeTrack(String playlistTrackId) {
    _bloc.add(PlaylistRemoveTrackRequested(playlistTrackId));
  }

  Future<void> _refreshPlaylist() async {
    _bloc.add(const PlaylistRefreshRequested());
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (_state.isReordering) return;

    if (_searchController.text.trim().isNotEmpty) {
      AppSnackbar.showError(context, 'Clear search to reorder the playlist.');
      return;
    }

    _bloc.add(
      PlaylistReorderRequested(oldIndex: oldIndex, newIndex: newIndex),
    );
  }

  Future<void> _openAddSongs() async {
    if (_isOfflineBlocked) return;
    if (!_guard(
      condition: !_permissions.canEditTracks,
      message: 'You do not have permission to edit this playlist.',
    )) {
      return;
    }

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PlaylistTrackSearchModal(
        dataSource: _dataSource,
        onAddTrack: _addTrack,
      ),
    );
  }

  Future<void> _openInviteUsers() async {
    if (_isOfflineBlocked) return;
    if (!_guard(
      condition: !_permissions.canManageCollaborators,
      message: 'Only the playlist creator can invite users.',
    )) {
      return;
    }

    final details = _state.details!;
    if (!_guard(
      condition: !_permissions.canInvite,
      message:
          'This playlist already has the maximum of '
          '${PlaylistDetailsEntity.maxCollaborators} collaborators.',
    )) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PlaylistUserInviteBottomSheet(
        playlistId: widget.playlistId,
        playlistName: details.name,
        currentUserId: _resolveUserId(context),
        initialCollaboratorIds: details.collaboratorIds,
      ),
    );
  }

  Future<void> _openSettings() async {
    if (_isOfflineBlocked) return;
    if (!_guard(
      condition: !_permissions.canManageSettings,
      message: 'Only the playlist creator can edit permissions.',
    )) {
      return;
    }

    final details = _state.details!;
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        builder: (_) => CreatePlaylistPage(
          playlist: details,
          initialGenres: details.tags,
        ),
      ),
    );

    if (!mounted || result == null) return;

    if (result == 'deleted') {
      AppSnackbar.showSuccess(context, 'Playlist deleted.');
      context.go('/playlists');
      return;
    }

    if (result == true) {
      _bloc.add(const PlaylistRefreshRequested());
    }
  }

  Future<bool> _addTrack(TrackSearchEntity track) async {
    if (_state.isAddingTrack) return false;

    setState(() => _state = _state.copyWith(isAddingTrack: true));

    final previousUpdatedAt = _bloc.state.latestUpdatedAt;
    final alreadyHasTrack =
        _bloc.state.playlist?.tracks.any(
          (t) => t.providerTrackId == track.providerTrackId,
        ) ??
        false;

    try {
      final completer = Completer<bool>();
      late final StreamSubscription<PlaylistState> sub;

      sub = _bloc.stream.listen((s) {
        if (completer.isCompleted) return;
        if (s.errorMessage != null) {
          completer.complete(false);
          return;
        }
        final playlist = s.playlist;
        if (playlist == null) return;

        final hasTrack = playlist.tracks.any(
          (t) => t.providerTrackId == track.providerTrackId,
        );
        final updatedAtChanged =
            s.latestUpdatedAt != null && s.latestUpdatedAt != previousUpdatedAt;

        if (!alreadyHasTrack && hasTrack && updatedAtChanged) {
          completer.complete(true);
        }
      });

      _bloc.add(PlaylistAddTrackRequested(track));

      final success = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );
      await sub.cancel();

      if (!mounted) return success;

      if (success) {
        AppSnackbar.showSuccess(context, 'Song added to playlist.');
      } else {
        AppSnackbar.showError(context, 'Failed to add song.');
      }
      return success;
    } on Object {
      if (mounted) AppSnackbar.showError(context, 'Failed to add song.');
      return false;
    } finally {
      if (mounted) {
        setState(() => _state = _state.copyWith(isAddingTrack: false));
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      builder: (context, screenSize) {
        final layout = _Layout(screenSize);
        return Scaffold(
          backgroundColor: _Token.pageBg(context),
          extendBodyBehindAppBar: true,
          appBar: _buildAppBar(context),
          body: SafeArea(
            top: false,
            child: _buildBody(context, layout),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
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
      leadingWidth: 64,
      leading: Padding(
        padding: const EdgeInsets.all(12),
        child: Tooltip(
          message: MaterialLocalizations.of(context).backButtonTooltip,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _Token.pageBg(context).withValues(alpha: 0.6),
              border: Border.all(
                color: _Token.borderSubtle(context).withValues(alpha: 0.33),
                width: 0.6,
              ),
            ),
            child: Center(
              child: AppBackButton(
                padding: EdgeInsets.zero,
                iconSize: 14,
                color: _Token.textPrimary(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, _Layout layout) {
    if (_state.isLoading) return const PlaylistDetailsSkeleton();

    if (_state.errorMessage != null) {
      return _ErrorState(
        message: _state.errorMessage!,
        onRetry: _refreshPlaylist,
      );
    }

    final details = _state.details;
    if (details == null) return const SizedBox.shrink();

    return _PlaylistContent(
      details: details,
      layout: layout,
      state: _state,
      permissions: _permissions,
      artworkUrl: _artworkUrl,
      visibleTracks: _visibleTracks,
      searchController: _searchController,
      onRefresh: _refreshPlaylist,
      onAddSongs: _openAddSongs,
      onInviteUsers: _openInviteUsers,
      onOpenSettings: _openSettings,
      onReorder: _onReorder,
      onRemoveTrack: _removeTrack,
      onTrackTap: (track, index) => AppSnackbar.showInfo(
        context,
        '${track.title} • ${track.artist ?? 'Unknown artist'} • '
        '${_formatDurationMs(track.durationMs)}',
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _PlaylistContent
// ---------------------------------------------------------------------------

class _PlaylistContent extends StatelessWidget {
  const _PlaylistContent({
    required this.details,
    required this.layout,
    required this.state,
    required this.permissions,
    required this.artworkUrl,
    required this.visibleTracks,
    required this.searchController,
    required this.onRefresh,
    required this.onAddSongs,
    required this.onInviteUsers,
    required this.onOpenSettings,
    required this.onReorder,
    required this.onRemoveTrack,
    required this.onTrackTap,
  });

  final PlaylistDetailsEntity details;
  final _Layout layout;
  final _PageState state;
  final _Permissions permissions;
  final String? artworkUrl;
  final List<PlaylistTrackEntity> visibleTracks;
  final TextEditingController searchController;
  final VoidCallback onRefresh;
  final VoidCallback onAddSongs;
  final VoidCallback onInviteUsers;
  final VoidCallback onOpenSettings;
  final Future<void> Function(int, int) onReorder;
  final void Function(String) onRemoveTrack;
  final void Function(PlaylistTrackEntity, int) onTrackTap;

  @override
  Widget build(BuildContext context) {
    final hp = layout.horizontalPadding;

    return ColoredBox(
      color: _Token.pageBg(context),
      child: Stack(
        children: [
          Column(
            children: [
              _StatusBanners(state: state),
              if (state.isSyncing || state.isReordering)
                LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: _Token.pageBg(context),
                  color: _Token.purple(context),
                ),
              Expanded(
                child: AbsorbPointer(
                  absorbing: state.isInteractionLocked,
                  child: RefreshIndicator(
                    color: _Token.purpleLight(context),
                    backgroundColor: _Token.cardBg(context),
                    onRefresh: () async => onRefresh(),
                    child: Scrollbar(
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          // Hero (gradient background section)
                          SliverToBoxAdapter(
                            child: _HeroBackground(
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: layout.contentMaxWidth,
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      hp,
                                      layout.isCompact ? 8 : 20,
                                      hp,
                                      28,
                                    ),
                                    child: _HeroSection(
                                      details: details,
                                      layout: layout,
                                      permissions: permissions,
                                      artworkUrl: artworkUrl,
                                      onAddSongs: onAddSongs,
                                      onInviteUsers: onInviteUsers,
                                      onOpenSettings: onOpenSettings,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Compact-only action row + search
                          if (layout.isCompact) ...[
                            _SliverSection(
                              horizontalPadding: hp,
                              topPadding: 16,
                              bottomPadding: 4,
                              maxWidth: layout.contentMaxWidth,
                              child: _CompactActionRow(
                                permissions: permissions,
                                onAddSongs: onAddSongs,
                                onInviteUsers: onInviteUsers,
                                onOpenSettings: onOpenSettings,
                              ),
                            ),
                            _SliverSection(
                              horizontalPadding: hp,
                              topPadding: 16,
                              maxWidth: layout.contentMaxWidth,
                              child: _SearchField(
                                controller: searchController,
                              ),
                            ),
                          ],

                          // Track section header
                          _SliverSection(
                            horizontalPadding: hp,
                            topPadding: layout.isCompact ? 24 : 28,
                            maxWidth: layout.contentMaxWidth,
                            child: _TrackSectionHeader(
                              title: layout.trackSectionTitle,
                              state: state,
                              permissions: permissions,
                              showIcon:
                                  layout.isWide && permissions.canEditTracks,
                            ),
                          ),

                          // Column header (wide only)
                          if (layout.showTrackColumnHeader &&
                              visibleTracks.isNotEmpty)
                            _SliverSection(
                              horizontalPadding: hp,
                              topPadding: 14,
                              bottomPadding: 8,
                              maxWidth: layout.contentMaxWidth,
                              child: const _TrackColumnHeader(),
                            ),

                          // Empty / track list
                          if (visibleTracks.isEmpty)
                            _SliverSection(
                              horizontalPadding: hp,
                              topPadding: layout.isCompact ? 16 : 24,
                              bottomPadding: 24,
                              fillRemaining: true,
                              maxWidth: layout.contentMaxWidth,
                              child: _EmptyTracksState(
                                query: searchController.text.trim(),
                                canAddSong: permissions.canEditTracks,
                                onAddSong: onAddSongs,
                              ),
                            )
                          else
                            _TrackList(
                              tracks: visibleTracks,
                              layout: layout,
                              state: state,
                              permissions: permissions,
                              onReorder: onReorder,
                              onRemoveTrack: onRemoveTrack,
                              onTrackTap: onTrackTap,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (state.isReordering) const _ReorderingOverlay(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _HeroBackground — gradient container behind hero content
// ---------------------------------------------------------------------------

class _HeroBackground extends StatelessWidget {
  const _HeroBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    if (!isDark) {
      // Light mode: use a single very-light purple (from colorScheme.secondary)
      return ColoredBox(
        color: Theme.of(context).colorScheme.secondary,
        child: child,
      );
    }

    // Dark mode: keep the existing rich gradient
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _Token.heroGradientTop(context),
            _Token.heroGradientMid(context),
            _Token.pageBg(context),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// _SliverSection
// ---------------------------------------------------------------------------

class _SliverSection extends StatelessWidget {
  const _SliverSection({
    required this.child,
    required this.maxWidth,
    this.horizontalPadding = 20,
    this.topPadding = 0,
    this.bottomPadding = 0,
    this.fillRemaining = false,
  });

  final Widget child;
  final double maxWidth;
  final double horizontalPadding;
  final double topPadding;
  final double bottomPadding;
  final bool fillRemaining;

  @override
  Widget build(BuildContext context) {
    final constrained = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        topPadding,
        horizontalPadding,
        bottomPadding,
      ),
      sliver: fillRemaining
          ? SliverFillRemaining(hasScrollBody: false, child: constrained)
          : SliverToBoxAdapter(child: constrained),
    );
  }
}

// ---------------------------------------------------------------------------
// _StatusBanners
// ---------------------------------------------------------------------------

class _StatusBanners extends StatelessWidget {
  const _StatusBanners({required this.state});

  final _PageState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.isOffline)
          const _Banner(
            text: 'You are offline — playlist is read-only.',
            background: Color(0xFF3B1010),
            foreground: Color(0xFFFFB4AB),
          ),
        if (state.showStaleWarning)
          const _Banner(
            text: 'This playlist may be outdated.',
            background: Color(0xFF2A1F0A),
            foreground: Color(0xFFFFD8A8),
          ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: background,
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _HeroSection
// ---------------------------------------------------------------------------

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.details,
    required this.layout,
    required this.permissions,
    required this.artworkUrl,
    required this.onAddSongs,
    required this.onInviteUsers,
    required this.onOpenSettings,
  });

  final PlaylistDetailsEntity details;
  final _Layout layout;
  final _Permissions permissions;
  final String? artworkUrl;
  final VoidCallback onAddSongs;
  final VoidCallback onInviteUsers;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final artwork = ClipRRect(
      borderRadius: BorderRadius.circular(_Token.radiusArtwork),
      child: _PlaylistArtwork(
        imageUrl: artworkUrl,
        size: layout.heroImageHeight,
        isCompact: layout.isCompact,
      ),
    );

    final info = _HeroInfo(
      details: details,
      layout: layout,
      permissions: permissions,
      onAddSongs: onAddSongs,
      onInviteUsers: onInviteUsers,
      onOpenSettings: onOpenSettings,
    );

    if (layout.isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: double.infinity, child: artwork),
          const SizedBox(height: 16),
          info,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: layout.heroImageSize,
          height: layout.heroImageHeight,
          child: artwork,
        ),
        const SizedBox(width: 28),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: info,
          ),
        ),
      ],
    );
  }
}

class _HeroInfo extends StatelessWidget {
  const _HeroInfo({
    required this.details,
    required this.layout,
    required this.permissions,
    required this.onAddSongs,
    required this.onInviteUsers,
    required this.onOpenSettings,
  });

  final PlaylistDetailsEntity details;
  final _Layout layout;
  final _Permissions permissions;
  final VoidCallback onAddSongs;
  final VoidCallback onInviteUsers;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final description = details.description?.trim();
    final isPublic = details.visibility == 'PUBLIC';
    final tags = TagGenreNormalizer.toDisplayLabels(details.tags);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Eyebrow
        Text(
          isPublic ? 'Public playlist' : 'Private playlist',
          style: TextStyle(
            color: _Token.textMuted(context),
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),

        // Title
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: layout.isCompact ? double.infinity : 500,
          ),
          child: Text(
            details.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _Token.textPrimary(context),
              fontSize: layout.titleFontSize,
              fontWeight: FontWeight.w500,
              height: 0.95,
              letterSpacing: -1.5,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Meta row
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${details.tracks.length} tracks · '
              '${_formatTotalDuration(details.tracks)}',
              style: TextStyle(
                color: _Token.textSecondary(context),
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
            ...tags.map((tag) => _TagChip(label: tag)),
          ],
        ),

        // Description
        if (description != null) ...[
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Text(
              description,
              style: TextStyle(
                color: _Token.textMuted(context),
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),
        ],

        // Actions (wide only)
        if (layout.showInlineHeroActions) ...[
          const SizedBox(height: 20),
          _HeroActions(
            permissions: permissions,
            onAddSongs: onAddSongs,
            onInviteUsers: onInviteUsers,
            onOpenSettings: onOpenSettings,
          ),
        ],
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: _Token.purple(context).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(_Token.radiusTag),
        border: Border.all(
          color: _Token.purple(context).withValues(alpha: 0.35),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _Token.purpleLight(context),
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _HeroActions — wide layout
// ---------------------------------------------------------------------------

class _HeroActions extends StatelessWidget {
  const _HeroActions({
    required this.permissions,
    required this.onAddSongs,
    required this.onInviteUsers,
    required this.onOpenSettings,
  });

  final _Permissions permissions;
  final VoidCallback onAddSongs;
  final VoidCallback onInviteUsers;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (permissions.canEditTracks)
          _PillButton(
            onPressed: onAddSongs,
            label: 'Add songs',
            icon: const AppBrandIcon(size: 16),
            filled: true,
          ),
        if (permissions.canInvite)
          _PillButton(
            onPressed: onInviteUsers,
            label: 'Invite',
            icon: const Icon(Icons.person_add_outlined),
            filled: false,
          ),
        if (permissions.canManageSettings)
          Tooltip(
            message: 'Playlist settings',
            child: _GlassIconButton(
              onPressed: onOpenSettings,
              icon: Icons.tune_outlined,
              size: 20,
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _CompactActionRow
// ---------------------------------------------------------------------------

class _CompactActionRow extends StatelessWidget {
  const _CompactActionRow({
    required this.permissions,
    required this.onAddSongs,
    required this.onInviteUsers,
    required this.onOpenSettings,
  });

  final _Permissions permissions;
  final VoidCallback onAddSongs;
  final VoidCallback onInviteUsers;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (permissions.canEditTracks) ...[
          _PillButton(
            onPressed: onAddSongs,
            label: 'Add',
            icon: const AppBrandIcon(size: 16),
            filled: true,
            compact: true,
          ),
          const SizedBox(width: 10),
        ],
        if (permissions.canInvite) ...[
          _PillButton(
            onPressed: onInviteUsers,
            label: 'Invite',
            icon: const Icon(Icons.person_add_outlined),
            filled: false,
            compact: true,
          ),
          const SizedBox(width: 10),
        ],
        if (permissions.canManageSettings)
          Tooltip(
            message: 'Playlist settings',
            child: _GlassIconButton(
              onPressed: onOpenSettings,
              icon: Icons.tune_outlined,
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared button primitives
// ---------------------------------------------------------------------------

/// Filled or ghost pill button used in both hero and compact action rows.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.onPressed,
    required this.label,
    required this.icon,
    required this.filled,
    this.compact = false,
  });

  final VoidCallback onPressed;
  final String label;
  final Widget icon;
  final bool filled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 36.0 : 36.0;
    final hPad = compact ? 14.0 : 18.0;
    const fontSize = 13.0;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: hPad),
        decoration: BoxDecoration(
          color: filled ? _Token.purple(context) : _Token.cardBg(context),
          borderRadius: BorderRadius.circular(_Token.radiusPill),
          border: Border.all(
            color: filled ? Colors.transparent : _Token.borderSubtle(context),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme.merge(
              data: IconThemeData(
                size: 16,
                color: filled ? Colors.white : _Token.textSecondary(context),
              ),
              child: icon,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: filled ? Colors.white : _Token.textSecondary(context),
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small circular glass-style icon button.
class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.onPressed,
    required this.icon,
    this.size = 18,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bg = _Token.cardBg(context);
    final border = _Token.borderSubtle(context);
    final ic = _Token.textSecondary(context);

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          border: Border.all(color: border, width: 0.5),
        ),
        child: Icon(icon, size: size, color: ic),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TrackSectionHeader
// ---------------------------------------------------------------------------

class _TrackSectionHeader extends StatelessWidget {
  const _TrackSectionHeader({
    required this.title,
    required this.state,
    required this.permissions,
    required this.showIcon,
  });

  final String title;
  final _PageState state;
  final _Permissions permissions;
  final bool showIcon;

  String get _subtitle {
    if (state.isOffline) return 'Read-only';
    if (!permissions.canEditTracks) return 'View-only';
    if (state.isReordering) return 'Updating order…';
    return 'Drag to reorder';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: _Token.textPrimary(context),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              Icon(
                Icons.drag_indicator_rounded,
                size: 14,
                color: _Token.textMuted(context),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              _subtitle,
              style: TextStyle(
                color: _Token.textMuted(context),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _TrackColumnHeader
// ---------------------------------------------------------------------------

class _TrackColumnHeader extends StatelessWidget {
  const _TrackColumnHeader();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: _Token.textMuted(context),
      fontSize: 10,
      fontWeight: FontWeight.w500,
      letterSpacing: 1.2,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          SizedBox(width: 32, child: Text('#', style: style)),
          Expanded(flex: 5, child: Text('TITLE', style: style)),
          Expanded(flex: 3, child: Text('ARTIST', style: style)),
          SizedBox(
            width: 80,
            child: Text('DURATION', style: style),
          ),
          SizedBox(
            width: 80,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('ACTIONS', style: style),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TrackList
// ---------------------------------------------------------------------------

class _TrackList extends StatelessWidget {
  const _TrackList({
    required this.tracks,
    required this.layout,
    required this.state,
    required this.permissions,
    required this.onReorder,
    required this.onRemoveTrack,
    required this.onTrackTap,
  });

  final List<PlaylistTrackEntity> tracks;
  final _Layout layout;
  final _PageState state;
  final _Permissions permissions;
  final Future<void> Function(int, int) onReorder;
  final void Function(String) onRemoveTrack;
  final void Function(PlaylistTrackEntity, int) onTrackTap;

  void _handleLockedReorder(BuildContext context) {
    final msg = state.isOffline
        ? 'You are offline. Playlist is read-only.'
        : 'Please wait until reordering completes.';
    AppSnackbar.showError(context, msg);
  }

  Widget _buildTrackTile(BuildContext context, int index) {
    final track = tracks[index];
    final isRemoving = state.removingTrackIds.contains(track.playlistTrackId);

    return Padding(
      key: ValueKey<String>(track.playlistTrackId),
      padding: const EdgeInsets.only(bottom: 6),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: layout.contentMaxWidth),
          child: _PlaylistTrackTile(
            index: index,
            track: track,
            isWideLayout: layout.isWide,
            canEdit: permissions.canEditTracks,
            canRemove: permissions.canRemoveTrack(track),
            isRemoving: isRemoving,
            onRemove: () {
              if (state.isInteractionLocked ||
                  !permissions.canRemoveTrack(track) ||
                  isRemoving) {
                final msg = state.isOffline
                    ? 'You are offline. Playlist is read-only.'
                    : state.isReordering
                    ? 'Please wait until reordering completes.'
                    : "You don't have permission to edit this.";
                AppSnackbar.showError(context, msg);
                return;
              }
              onRemoveTrack(track.playlistTrackId);
            },
            onTap: () => onTrackTap(track, index),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hp = layout.horizontalPadding;

    if (!permissions.canEditTracks) {
      return SliverPadding(
        padding: EdgeInsets.fromLTRB(hp, 0, hp, layout.isCompact ? 24 : 32),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            _buildTrackTile,
            childCount: tracks.length,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(hp, 0, hp, layout.isCompact ? 24 : 32),
      sliver: SliverReorderableList(
        itemCount: tracks.length,
        onReorderItem: state.isInteractionLocked
            ? (_, _) => _handleLockedReorder(context)
            : (oldIndex, newIndex) => unawaited(onReorder(oldIndex, newIndex)),
        itemBuilder: _buildTrackTile,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _PlaylistArtwork
// ---------------------------------------------------------------------------

class _PlaylistArtwork extends StatelessWidget {
  const _PlaylistArtwork({
    required this.imageUrl,
    required this.size,
    required this.isCompact,
  });

  final String? imageUrl;
  final double size;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl?.isNotEmpty == true;
    final effectiveWidth = isCompact ? double.infinity : size;

    if (hasImage) {
      return SizedBox(
        width: effectiveWidth,
        height: size,
        child: Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _ArtworkMosaic(
            width: effectiveWidth,
            height: size,
          ),
        ),
      );
    }

    return _ArtworkMosaic(width: effectiveWidth, height: size);
  }
}

/// 2×2 gradient mosaic — shown when no image is available.
class _ArtworkMosaic extends StatelessWidget {
  const _ArtworkMosaic({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GridView.count(
            crossAxisCount: 2,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(4, (i) {
              final colors = _Token.artworkGradients(context)[i];
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                ),
              );
            }),
          ),
          // Centered icon overlay (app branding)
          const Center(
            child: AppBrandIcon(size: 40),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _PlaylistTrackTile
// ---------------------------------------------------------------------------

class _PlaylistTrackTile extends StatelessWidget {
  const _PlaylistTrackTile({
    required this.index,
    required this.track,
    required this.isWideLayout,
    required this.canEdit,
    required this.canRemove,
    required this.isRemoving,
    required this.onRemove,
    required this.onTap,
  });

  final int index;
  final PlaylistTrackEntity track;
  final bool isWideLayout;
  final bool canEdit;
  final bool canRemove;
  final bool isRemoving;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = track.thumbnailUrl;

    final tile = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isWideLayout ? 14 : 12,
        vertical: isWideLayout ? 10 : 10,
      ),
      child: Row(
        children: [
          // Index
          SizedBox(
            width: 28,
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: _Token.textMuted(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Thumbnail
          _TrackThumbnail(thumbnailUrl: thumbnailUrl),
          const SizedBox(width: 10),

          // Title + artist
          Expanded(
            child: _TrackInfo(
              track: track,
              isWide: isWideLayout,
            ),
          ),

          // Duration
          const SizedBox(width: 12),
          SizedBox(
            width: 48,
            child: Text(
              _formatDurationMs(track.durationMs),
              style: TextStyle(
                color: _Token.textMuted(context),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),

          // Remove button
          if (canRemove)
            Tooltip(
              message: 'Remove track',
              child: _TrackActionButton(
                onPressed: isRemoving ? null : onRemove,
                child: isRemoving
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      )
                    : Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: _Token.textMuted(context),
                      ),
              ),
            ),
          const SizedBox(width: 4),

          // Drag handle
          if (canEdit)
            ReorderableDragStartListener(
              index: index,
              child: _TrackActionButton(
                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: 16,
                  color: _Token.textMuted(context),
                ),
              ),
            ),
        ],
      ),
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _Token.cardBg(context),
        borderRadius: BorderRadius.circular(_Token.radiusCard),
        border: Border.all(color: _Token.borderSubtle(context), width: 0.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: canEdit
            ? ReorderableDelayedDragStartListener(
                index: index,
                child: InkWell(
                  borderRadius: BorderRadius.circular(_Token.radiusCard),
                  splashColor: _Token.purple(context).withValues(alpha: 0.08),
                  highlightColor: _Token.cardBgHover(context),
                  onTap: onTap,
                  child: tile,
                ),
              )
            : InkWell(
                borderRadius: BorderRadius.circular(_Token.radiusCard),
                splashColor: _Token.purple(context).withValues(alpha: 0.08),
                highlightColor: _Token.cardBgHover(context),
                onTap: onTap,
                child: tile,
              ),
      ),
    );
  }
}

class _TrackThumbnail extends StatelessWidget {
  const _TrackThumbnail({required this.thumbnailUrl});

  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: thumbnailUrl != null && thumbnailUrl!.isNotEmpty
            ? Image.network(
                thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: _Token.cardBg(context),
                  child: const Center(
                    child: AppBrandIcon(size: 16),
                  ),
                ),
              )
            : ColoredBox(
                color: _Token.cardBg(context),
                child: const Center(
                  child: AppBrandIcon(size: 16),
                ),
              ),
      ),
    );
  }
}

class _TrackActionButton extends StatelessWidget {
  const _TrackActionButton({required this.child, this.onPressed});

  final Widget child;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _TrackInfo extends StatelessWidget {
  const _TrackInfo({required this.track, required this.isWide});

  final PlaylistTrackEntity track;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _Token.textPrimary(context),
            fontSize: isWide ? 14 : 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          track.artist ?? 'Unknown artist',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _Token.textMuted(context),
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _SearchField
// ---------------------------------------------------------------------------

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      style: TextStyle(color: _Token.textPrimary(context), fontSize: 13),
      cursorColor: _Token.purpleLight(context),
      decoration: InputDecoration(
        hintText: 'Search songs in playlist…',
        hintStyle: TextStyle(color: _Token.textMuted(context), fontSize: 13),
        prefixIcon: Icon(
          Icons.search,
          size: 18,
          color: _Token.textMuted(context),
        ),
        suffixIcon: controller.text.trim().isNotEmpty
            ? GestureDetector(
                onTap: controller.clear,
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: _Token.textMuted(context),
                ),
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        filled: true,
        fillColor: _Token.cardBg(context),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_Token.radiusSearch),
          borderSide: BorderSide(
            color: _Token.borderSubtle(context),
            width: 0.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_Token.radiusSearch),
          borderSide: BorderSide(
            color: _Token.purple(context),
            width: 0.5,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ReorderingOverlay
// ---------------------------------------------------------------------------

class _ReorderingOverlay extends StatelessWidget {
  const _ReorderingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: _Token.pageBg(context).withValues(alpha: 0.6),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1230),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _Token.borderSubtle(context),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: _Token.purpleLight(context),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Updating track order…',
                  style: TextStyle(
                    color: _Token.textSecondary(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ErrorState
// ---------------------------------------------------------------------------

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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
            const Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: Color(0xFFFF6B6B),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _Token.textSecondary(context),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _Token.purple(context).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(_Token.radiusPill),
                  border: Border.all(
                    color: _Token.purple(context).withValues(alpha: 0.35),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: _Token.purpleLight(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Try again',
                      style: TextStyle(
                        color: _Token.purpleLight(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _EmptyTracksState
// ---------------------------------------------------------------------------

class _EmptyTracksState extends StatelessWidget {
  const _EmptyTracksState({
    required this.query,
    required this.canAddSong,
    required this.onAddSong,
  });

  final String query;
  final bool canAddSong;
  final VoidCallback onAddSong;

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.isNotEmpty;
    final message = hasQuery
        ? 'No songs match "$query".\nTry another search term.'
        : canAddSong
        ? 'This playlist is empty.\nAdd tracks to get started.'
        : 'This playlist is empty.\n'
              'You can only view tracks once the creator adds them.';

    return EmptyStateWidget(
      icon: Icons.library_music_outlined,
      message: message,
      actionLabel: !hasQuery && canAddSong ? 'Add Songs' : null,
      onActionPressed: !hasQuery && canAddSong ? onAddSong : null,
    );
  }
}
