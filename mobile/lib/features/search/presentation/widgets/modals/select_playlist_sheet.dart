import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/playlist/data/datasources/playlist_remote_datasource.dart'
    show IPlaylistRemoteDataSource;
import 'package:music_room/features/playlist/domain/entities/playlist_entity.dart';

class SelectPlaylistSheet extends StatefulWidget {
  const SelectPlaylistSheet({super.key});

  @override
  State<SelectPlaylistSheet> createState() => _SelectPlaylistSheetState();
}

class _SelectPlaylistSheetState extends State<SelectPlaylistSheet> {
  final IPlaylistRemoteDataSource _playlistDs =
      InjectionContainer().playlistRemoteDataSource;

  List<PlaylistEntity> _playlists = const <PlaylistEntity>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items = await _playlistDs.fetchMyPlaylists();
      if (!mounted) return;
      setState(() {
        _playlists = items;
        _isLoading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      final message = data is Map<String, dynamic>
          ? data['message'] as String?
          : null;
      setState(() {
        _isLoading = false;
        _error = message ?? 'Unable to load playlists.';
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Unable to load playlists.';
      });
    }
  }

  Widget _buildPlaylistThumbnail(
    BuildContext context,
    PlaylistEntity p,
  ) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
      ),
      child: p.thumbnailUrl != null && p.thumbnailUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                p.thumbnailUrl!,
                fit: BoxFit.cover,
              ),
            )
          : Icon(
              Icons.queue_music,
              color: Theme.of(context).colorScheme.primary,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context);
    final bottomInset = insets.viewInsets.bottom + 16;
    final sheetHeight = insets.size.height * 0.6;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset),
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add to playlist',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!))
                  : _playlists.isEmpty
                  ? const Center(
                      child: Text('You have no playlists yet.'),
                    )
                  : ListView.separated(
                      itemCount: _playlists.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final p = _playlists[index];
                        return ListTile(
                          leading: _buildPlaylistThumbnail(
                            context,
                            p,
                          ),
                          title: Text(p.name),
                          subtitle: Text(
                            '${p.trackCount} tracks • '
                            '${p.visibility.toLowerCase()}',
                          ),
                          onTap: () =>
                              Navigator.of(context).pop<PlaylistEntity>(p),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
