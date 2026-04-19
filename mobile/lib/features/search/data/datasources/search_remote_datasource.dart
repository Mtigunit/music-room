import 'package:music_room/core/config/app_config.dart';
import 'package:music_room/core/network/api_client.dart';

enum SearchFilterType { tracks, users, events, playlists }

class SearchResultItem {
  const SearchResultItem({
    required this.title,
    required this.subtitle,
    required this.filterType,
    this.imageUrl,
    this.meta,
  });

  final String title;
  final String subtitle;
  final SearchFilterType filterType;
  final String? imageUrl;
  final String? meta;
}

abstract class ISearchRemoteDataSource {
  Future<List<SearchResultItem>> searchEvents(String query);
  Future<List<SearchResultItem>> searchTracks(String query);
  Future<List<SearchResultItem>> searchPlaylists(String query);
  Future<List<SearchResultItem>> searchUsers(String query);
}

class SearchRemoteDataSource implements ISearchRemoteDataSource {
  SearchRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  static const List<SearchResultItem> _mockEvents = <SearchResultItem>[
    SearchResultItem(
      title: 'Sunset Rooftop Session',
      subtitle: 'Afro house night in Brooklyn',
      filterType: SearchFilterType.events,
      meta: 'Tonight 8:30 PM',
    ),
    SearchResultItem(
      title: 'Vinyl & Coffee Meetup',
      subtitle: 'Bring your favorite crate finds',
      filterType: SearchFilterType.events,
      meta: 'Saturday',
    ),
    SearchResultItem(
      title: 'Campus Open Decks',
      subtitle: 'Student DJs and live requests',
      filterType: SearchFilterType.events,
      meta: 'Free entry',
    ),
  ];

  static const List<SearchResultItem> _mockPlaylists = <SearchResultItem>[
    SearchResultItem(
      title: 'Late Night Drive',
      subtitle: 'Synthwave and alt pop blend',
      filterType: SearchFilterType.playlists,
      meta: '42 tracks',
    ),
    SearchResultItem(
      title: 'Gym Bass Boost',
      subtitle: 'High energy EDM and trap',
      filterType: SearchFilterType.playlists,
      meta: '58 tracks',
    ),
    SearchResultItem(
      title: 'Lo-Fi Focus',
      subtitle: 'Calm beats for deep work',
      filterType: SearchFilterType.playlists,
      meta: '31 tracks',
    ),
  ];

  static const List<SearchResultItem> _mockUsers = <SearchResultItem>[
    SearchResultItem(
      title: 'mia_dj',
      subtitle: 'Mia Thompson',
      filterType: SearchFilterType.users,
      meta: 'Host',
    ),
    SearchResultItem(
      title: 'beatbuilder',
      subtitle: 'Carlos Rivera',
      filterType: SearchFilterType.users,
      meta: 'Producer',
    ),
    SearchResultItem(
      title: 'nocturne.ana',
      subtitle: 'Ana Martins',
      filterType: SearchFilterType.users,
      meta: 'DJ',
    ),
  ];

  @override
  Future<List<SearchResultItem>> searchTracks(String query) async {
    final response = await _apiClient.get<List<dynamic>>(
      AppConfig.trackSearchEndpoint,
      queryParameters: {'q': query},
    );

    final data = response.data;
    if (data == null) {
      return const <SearchResultItem>[];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => SearchResultItem(
            title: _safeString(item['title'], fallback: 'Untitled Track'),
            subtitle: _safeString(item['artist'], fallback: 'Unknown Artist'),
            filterType: SearchFilterType.tracks,
            imageUrl: _nullableString(item['thumbnailUrl']),
            meta: _formatDuration(item['durationMs']),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<SearchResultItem>> searchEvents(String query) async {
    return _searchMockItems(_mockEvents, query);
  }

  @override
  Future<List<SearchResultItem>> searchPlaylists(String query) async {
    return _searchMockItems(_mockPlaylists, query);
  }

  @override
  Future<List<SearchResultItem>> searchUsers(String query) async {
    return _searchMockItems(_mockUsers, query);
  }

  List<SearchResultItem> _searchMockItems(
    List<SearchResultItem> source,
    String query,
  ) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return const <SearchResultItem>[];
    }

    return source
        .where((item) {
          final searchable = '${item.title} ${item.subtitle} ${item.meta ?? ''}'
              .toLowerCase();
          return searchable.contains(normalizedQuery);
        })
        .toList(growable: false);
  }

  String _safeString(Object? value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }

  String? _nullableString(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  String? _formatDuration(Object? rawValue) {
    if (rawValue is! num) {
      return null;
    }

    final totalSeconds = (rawValue / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }
}
