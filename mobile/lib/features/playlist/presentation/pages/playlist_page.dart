import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room/core/widgets/app_button.dart';
import 'package:music_room/core/widgets/empty_state_widget.dart';
import 'package:music_room/core/widgets/premium_segmented_tab_bar.dart';
import 'package:music_room/core/widgets/responsive_layout.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/auth/presentation/state/auth_state.dart';
import 'package:music_room/features/playlist/data/datasources/playlist_remote_datasource.dart';
import 'package:music_room/features/playlist/domain/entities/playlist_entity.dart';
import 'package:music_room/features/playlist/presentation/widgets/playlist_collage_image.dart';
import 'package:music_room/features/playlist/presentation/widgets/skeletons/playlist_page_skeleton.dart';
import 'package:music_room/routes/route_names.dart';

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({super.key});

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  final IPlaylistRemoteDataSource _playlistDataSource =
      InjectionContainer().playlistRemoteDataSource;

  List<PlaylistEntity> _playlists = const <PlaylistEntity>[];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPlaylists());
  }

  Future<void> _loadPlaylists() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final playlists = await _playlistDataSource.fetchMyPlaylists();

      if (!mounted) {
        return;
      }

      setState(() {
        _playlists = playlists;
        _isLoading = false;
      });
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = _networkErrorMessage(error);
      });
    } on Object {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load your playlists right now.';
      });
    }
  }

  String _networkErrorMessage(DioException error) {
    if (error.response?.statusCode == 401) {
      return 'Please sign in again to view your playlists.';
    }

    return 'Unable to load your playlists right now.';
  }

  String? _currentUserIdFromAuthState(AuthState state) {
    if (state is AuthAuthenticated) {
      return state.user.id;
    }
    if (state is LoginSuccess) {
      return state.user.id;
    }
    if (state is RegisterSuccess) {
      return state.user.id;
    }
    if (state is GoogleLoginSuccess) {
      return state.user.id;
    }
    return null;
  }

  void _openCreatePlaylistPage() {
    unawaited(
      context
          .push<void>('${RouteNames.playlists}/create')
          .then((_) => _loadPlaylists()),
    );
  }

  void _openPlaylistDetails(PlaylistEntity playlist) {
    unawaited(
      context
          .push<void>('${RouteNames.playlists}/${playlist.id}')
          .then((_) => _loadPlaylists()),
    );
  }

  Future<void> _showPlaylistSearchModal() async {
    final selectedPlaylist = await showModalBottomSheet<PlaylistEntity>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _PlaylistSearchModalSheet(
        playlistDataSource: _playlistDataSource,
      ),
    );

    if (selectedPlaylist != null && mounted) {
      _openPlaylistDetails(selectedPlaylist);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentUserId = _currentUserIdFromAuthState(
      context.watch<AuthBloc>().state,
    );

    final createdPlaylists = currentUserId == null
        ? const <PlaylistEntity>[]
        : _playlists
              .where((playlist) => playlist.ownerUserId == currentUserId)
              .toList(growable: false);
    final invitedPlaylists = currentUserId == null
        ? const <PlaylistEntity>[]
        : _playlists
              .where((playlist) => playlist.ownerUserId != currentUserId)
              .toList(growable: false);

    return ResponsiveLayout(
      builder: (context, screenSize) {
        return Scaffold(
          body: screenSize == ScreenSize.compact
              ? _buildMobileLayout(
                  colorScheme,
                  textTheme,
                  createdPlaylists,
                  invitedPlaylists,
                )
              : _buildDesktopLayout(
                  colorScheme,
                  textTheme,
                  createdPlaylists,
                  invitedPlaylists,
                  screenSize,
                ),
          floatingActionButton: screenSize == ScreenSize.compact
              ? FloatingActionButton(
                  heroTag: null,
                  onPressed: _showPlaylistSearchModal,
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  child: const Icon(Icons.search),
                )
              : null,
        );
      },
    );
  }

  Widget _buildMobileLayout(
    ColorScheme colorScheme,
    TextTheme textTheme,
    List<PlaylistEntity> createdPlaylists,
    List<PlaylistEntity> invitedPlaylists,
  ) {
    return SafeArea(
      child: DefaultTabController(
        length: 2,
        child: Builder(
          builder: (context) {
            final tabController = DefaultTabController.of(context);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
                  child: Text(
                    'My Playlists',
                    style: textTheme.displaySmall?.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: PremiumSegmentedTabBar(
                    onTap: (_) => unawaited(_loadPlaylists()),
                    tabs: const [
                      Tab(text: 'Created'),
                      Tab(text: 'Invited'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: AnimatedBuilder(
                    animation: tabController,
                    builder: (context, _) {
                      final isCreatedTabSelected = tabController.index == 0;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isCreatedTabSelected) ...[
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 26,
                              ),
                              child: SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _openCreatePlaylistPage,
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        12,
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Create Playlist'),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Expanded(
                            child: _isLoading
                                ? const PlaylistPageSkeleton()
                                : _errorMessage != null
                                ? EmptyStateWidget(
                                    icon: Icons.error_outline,
                                    message: _errorMessage!,
                                    actionLabel: 'Try again',
                                    onActionPressed: () {
                                      unawaited(_loadPlaylists());
                                    },
                                  )
                                : TabBarView(
                                    children: [
                                      _PlaylistTab(
                                        playlists: createdPlaylists,
                                        emptyIcon: Icons.queue_music_rounded,
                                        emptyMessage:
                                            'No playlists created yet.\n'
                                            'Start building your first '
                                            'vibe.',
                                        onRefresh: _loadPlaylists,
                                        onPlaylistTap: _openPlaylistDetails,
                                        screenSize: ScreenSize.compact,
                                      ),
                                      _PlaylistTab(
                                        playlists: invitedPlaylists,
                                        emptyIcon: Icons.group_outlined,
                                        emptyMessage:
                                            'No playlist invites yet.\n'
                                            'Collaborative playlists will '
                                            'appear here.',
                                        onRefresh: _loadPlaylists,
                                        onPlaylistTap: _openPlaylistDetails,
                                        screenSize: ScreenSize.compact,
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(
    ColorScheme colorScheme,
    TextTheme textTheme,
    List<PlaylistEntity> createdPlaylists,
    List<PlaylistEntity> invitedPlaylists,
    ScreenSize screenSize,
  ) {
    return SafeArea(
      child: DefaultTabController(
        length: 2,
        child: Builder(
          builder: (context) {
            final tabController = DefaultTabController.of(context);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Playlists',
                        style: textTheme.displaySmall?.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          height: 1,
                        ),
                      ),

                      const SizedBox(height: 20),

                      AnimatedBuilder(
                        animation: tabController,
                        builder: (context, _) {
                          final isCreatedTabSelected = tabController.index == 0;

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              PremiumSegmentedTabBar(
                                width: 340,
                                margin: EdgeInsets.zero,
                                onTap: (_) => unawaited(_loadPlaylists()),
                                tabs: const [
                                  Tab(text: 'Created'),
                                  Tab(text: 'Invited'),
                                ],
                              ),

                              if (isCreatedTabSelected)
                                AppButton(
                                  onPressed: _openCreatePlaylistPage,
                                  height: 40,
                                  borderRadius: 999,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF8B3DFF),
                                      Color(0xFF6F2CFF),
                                    ],
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  leading: const Icon(
                                    Icons.add_rounded,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                  label: 'Create Playlist',
                                  textStyle: textTheme.titleSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              else
                                const SizedBox.shrink(),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                Expanded(
                  child: AnimatedBuilder(
                    animation: tabController,
                    builder: (context, _) {
                      return _isLoading
                          ? PlaylistPageSkeleton(
                              screenSize: screenSize,
                            )
                          : _errorMessage != null
                          ? Center(
                              child: EmptyStateWidget(
                                icon: Icons.error_outline,
                                message: _errorMessage!,
                                actionLabel: 'Try again',
                                onActionPressed: () {
                                  unawaited(
                                    _loadPlaylists(),
                                  );
                                },
                              ),
                            )
                          : TabBarView(
                              children: [
                                _PlaylistTab(
                                  playlists: createdPlaylists,
                                  emptyIcon: Icons.queue_music_rounded,
                                  emptyMessage:
                                      'No playlists created yet.\n'
                                      'Start building your first vibe.',
                                  onRefresh: _loadPlaylists,
                                  onPlaylistTap: _openPlaylistDetails,
                                  screenSize: screenSize,
                                ),
                                _PlaylistTab(
                                  playlists: invitedPlaylists,
                                  emptyIcon: Icons.group_outlined,
                                  emptyMessage:
                                      'No playlist invites yet.\n'
                                      'Collaborative playlists '
                                      'will appear here.',
                                  onRefresh: _loadPlaylists,
                                  onPlaylistTap: _openPlaylistDetails,
                                  screenSize: screenSize,
                                ),
                              ],
                            );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PlaylistTab extends StatelessWidget {
  const _PlaylistTab({
    required this.playlists,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.onRefresh,
    required this.onPlaylistTap,
    required this.screenSize,
  });

  final List<PlaylistEntity> playlists;
  final IconData emptyIcon;
  final String emptyMessage;
  final Future<void> Function() onRefresh;
  final void Function(PlaylistEntity playlist) onPlaylistTap;
  final ScreenSize screenSize;

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: EmptyStateWidget(
              icon: emptyIcon,
              message: emptyMessage,
            ),
          ),
        ),
      );
    }

    if (screenSize == ScreenSize.compact) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            return _PlaylistListTile(
              playlist: playlist,
              onTap: () {
                onPlaylistTap(playlist);
              },
            );
          },
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemCount: playlists.length,
        ),
      );
    }

    // Desktop/Tablet grid layout
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(40, 12, 40, 40),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: screenSize == ScreenSize.expanded ? 3 : 2,
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
          childAspectRatio: 0.75,
        ),
        itemBuilder: (context, index) {
          final playlist = playlists[index];
          return _PlaylistGridCard(
            playlist: playlist,
            onTap: () {
              onPlaylistTap(playlist);
            },
          );
        },
        itemCount: playlists.length,
      ),
    );
  }
}

class _PlaylistGridCard extends StatefulWidget {
  const _PlaylistGridCard({
    required this.playlist,
    required this.onTap,
  });

  final PlaylistEntity playlist;
  final VoidCallback onTap;

  @override
  State<_PlaylistGridCard> createState() => _PlaylistGridCardState();
}

class _PlaylistGridCardState extends State<_PlaylistGridCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
      },
      onExit: (_) {
        setState(() => _isHovered = false);
      },
      child: FocusableActionDetector(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
          LogicalKeySet(LogicalKeyboardKey.space): const ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (intent) {
              widget.onTap();
              return null;
            },
          ),
        },
        onShowFocusHighlight: (focused) => setState(() => _isFocused = focused),
        onShowHoverHighlight: (hovering) =>
            setState(() => _isHovered = hovering),
        child: Semantics(
          button: true,
          focusable: true,
          onTap: widget.onTap,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (_isHovered || _isFocused)
                      ? colorScheme.primary.withValues(alpha: 0.3)
                      : colorScheme.onSurface.withValues(alpha: 0.08),
                ),
                color: Theme.of(context).cardColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                            color: colorScheme.secondary.withValues(
                              alpha: 0.75,
                            ),
                          ),
                          child: PlaylistCollageImage(
                            thumbnailUrl: widget.playlist.thumbnailUrl,
                            collageImageUrls: widget.playlist.collageImageUrls,
                            size: double.infinity,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                        ),
                        if (_isHovered)
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                              color: Colors.black.withValues(alpha: 0.3),
                            ),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.play_arrow,
                                  color: colorScheme.onPrimary,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.playlist.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${widget.playlist.trackCount} tracks • '
                          '${widget.playlist.visibility.toLowerCase()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(
                              alpha: 0.65,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistSearchModalSheet extends StatefulWidget {
  const _PlaylistSearchModalSheet({
    required this.playlistDataSource,
  });

  final IPlaylistRemoteDataSource playlistDataSource;

  @override
  State<_PlaylistSearchModalSheet> createState() =>
      _PlaylistSearchModalSheetState();
}

class _PlaylistSearchModalSheetState extends State<_PlaylistSearchModalSheet> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounceTimer;

  List<PlaylistEntity> _results = const <PlaylistEntity>[];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _errorMessage;
  int _searchRevision = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleQueryChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller
      ..removeListener(_handleQueryChanged)
      ..dispose();
    super.dispose();
  }

  void _handleQueryChanged() {
    final query = _controller.text.trim();
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _results = const <PlaylistEntity>[];
        _isLoading = false;
        _hasSearched = false;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _errorMessage = null;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(_searchPlaylists(query));
    });
  }

  Future<void> _searchPlaylists(String query) async {
    final revision = ++_searchRevision;

    try {
      final results = await widget.playlistDataSource.searchPublicPlaylists(
        query,
      );

      if (!mounted || revision != _searchRevision) {
        return;
      }

      setState(() {
        _results = results;
        _isLoading = false;
      });
    } on DioException catch (error) {
      if (!mounted || revision != _searchRevision) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = _searchErrorMessage(error);
      });
    } on Object {
      if (!mounted || revision != _searchRevision) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to search playlists right now.';
      });
    }
  }

  String _searchErrorMessage(DioException error) {
    if (error.response?.statusCode == 401) {
      return 'Please sign in again to search playlists.';
    }

    return 'Unable to search playlists right now.';
  }

  void _retrySearch() {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    unawaited(_searchPlaylists(query));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _controller.text.trim();
    final hasQuery = query.isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search playlists',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search public playlists...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: hasQuery
                    ? IconButton(
                        onPressed: _controller.clear,
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: !_hasSearched && query.isEmpty
                    ? const EmptyStateWidget(
                        icon: Icons.explore_outlined,
                        message:
                            'Search public playlists by name or tags.\n'
                            'Results will appear here as you type.',
                      )
                    : _errorMessage != null
                    ? EmptyStateWidget(
                        icon: Icons.cloud_off_rounded,
                        message: _errorMessage!,
                        actionLabel: 'Retry',
                        onActionPressed: _retrySearch,
                      )
                    : _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                    ? const EmptyStateWidget(
                        icon: Icons.playlist_play_outlined,
                        message: 'Try a different playlist name or keyword.',
                      )
                    : ListView.separated(
                        key: const ValueKey<String>('playlist-search-results'),
                        itemCount: _results.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final playlist = _results[index];
                          return _PlaylistListTile(
                            playlist: playlist,
                            onTap: () {
                              Navigator.of(context).pop(playlist);
                            },
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistListTile extends StatelessWidget {
  const _PlaylistListTile({
    required this.playlist,
    required this.onTap,
  });

  final PlaylistEntity playlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              PlaylistCollageImage(
                thumbnailUrl: playlist.thumbnailUrl,
                collageImageUrls: playlist.collageImageUrls,
                size: 64,
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${playlist.trackCount} tracks • '
                      '${playlist.visibility.toLowerCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
