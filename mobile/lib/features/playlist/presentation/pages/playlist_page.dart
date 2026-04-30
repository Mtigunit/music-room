import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/widgets/empty_state_widget.dart';
import 'package:music_room/core/widgets/premium_segmented_tab_bar.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/auth/presentation/state/auth_state.dart';
import 'package:music_room/features/playlist/data/datasources/playlist_remote_datasource.dart';
import 'package:music_room/features/playlist/domain/entities/playlist_entity.dart';
import 'package:music_room/features/playlist/presentation/pages/create_playlist_page.dart';
import 'package:music_room/features/playlist/presentation/pages/playlist_details_page.dart';

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

  Future<void> _openCreatePlaylistPage() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const CreatePlaylistPage(),
      ),
    );

    if (created == true && mounted) {
      await _loadPlaylists();
    }
  }

  Future<void> _openPlaylistDetails(PlaylistEntity playlist) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PlaylistDetailsPage(
          playlistId: playlist.id,
          playlistName: playlist.name,
        ),
      ),
    );

    if (mounted) {
      await _loadPlaylists();
    }
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
      unawaited(_openPlaylistDetails(selectedPlaylist));
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
        ? _playlists
        : _playlists
              .where((playlist) => playlist.ownerUserId == currentUserId)
              .toList(growable: false);
    final invitedPlaylists = currentUserId == null
        ? const <PlaylistEntity>[]
        : _playlists
              .where(
                (playlist) =>
                    playlist.ownerUserId != null &&
                    playlist.ownerUserId != currentUserId,
              )
              .toList(growable: false);

    return Scaffold(
      body: SafeArea(
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
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showPlaylistSearchModal,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        child: const Icon(Icons.search),
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
  });

  final List<PlaylistEntity> playlists;
  final IconData emptyIcon;
  final String emptyMessage;
  final Future<void> Function() onRefresh;
  final Future<void> Function(PlaylistEntity playlist) onPlaylistTap;

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
              unawaited(onPlaylistTap(playlist));
            },
          );
        },
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemCount: playlists.length,
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
    final hasThumbnail =
        playlist.thumbnailUrl != null && playlist.thumbnailUrl!.isNotEmpty;

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
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: colorScheme.secondary.withValues(alpha: 0.75),
                ),
                child: hasThumbnail
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          playlist.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.queue_music,
                            color: colorScheme.primary,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.queue_music,
                        color: colorScheme.primary,
                      ),
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
