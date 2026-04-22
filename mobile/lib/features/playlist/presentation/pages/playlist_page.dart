import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:music_room/di/injection_container.dart';
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadPlaylists,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Text(
                    'My Playlists',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _PlaylistMessageState(
                    icon: Icons.error_outline,
                    title: 'Could not load playlists',
                    message: _errorMessage!,
                    actionLabel: 'Try again',
                    onAction: () {
                      unawaited(_loadPlaylists());
                    },
                  ),
                )
              else if (_playlists.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _PlaylistMessageState(
                    icon: Icons.queue_music,
                    title: 'No playlists yet',
                    message:
                        'Create your first playlist to start organizing '
                        'your tracks.',
                    actionLabel: 'Create playlist',
                    onAction: _openCreatePlaylistPage,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                  sliver: SliverList.separated(
                    itemBuilder: (context, index) {
                      final playlist = _playlists[index];
                      return _PlaylistListTile(
                        playlist: playlist,
                        onTap: () {
                          unawaited(_openPlaylistDetails(playlist));
                        },
                      );
                    },
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemCount: _playlists.length,
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreatePlaylistPage,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        child: const Icon(Icons.add),
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

class _PlaylistMessageState extends StatelessWidget {
  const _PlaylistMessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.68),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
