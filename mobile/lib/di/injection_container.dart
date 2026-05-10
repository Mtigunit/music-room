import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:music_room/core/config/app_config.dart';
import 'package:music_room/core/network/api_client.dart';
import 'package:music_room/core/realtime/socket_client.dart';
import 'package:music_room/core/services/client_meta_service.dart';
import 'package:music_room/core/services/connectivity_service.dart';
import 'package:music_room/core/services/google_auth_service.dart';
import 'package:music_room/core/services/token_storage_service.dart';
import 'package:music_room/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:music_room/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:music_room/features/auth/domain/repositories/auth_repository.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/events/data/datasources/event_remote_datasource.dart';
import 'package:music_room/features/events/data/datasources/track_remote_datasource.dart';
import 'package:music_room/features/events/domain/repositories/event_repository.dart';
import 'package:music_room/features/music_vote/data/datasources/music_vote_remote_datasource.dart';
import 'package:music_room/features/music_vote/data/repositories/music_vote_repository_impl.dart';
import 'package:music_room/features/music_vote/domain/repositories/music_vote_repository.dart';
import 'package:music_room/features/playlist/data/datasources/playlist_cache_datasource.dart';
import 'package:music_room/features/playlist/data/datasources/playlist_remote_datasource.dart';
import 'package:music_room/features/playlist/presentation/state/playlist_bloc.dart';
import 'package:music_room/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:music_room/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:music_room/features/profile/domain/repositories/profile_repository.dart';
import 'package:music_room/features/profile/presentation/state/profile_bloc.dart';
import 'package:music_room/features/search/data/datasources/search_remote_datasource.dart';
import 'package:music_room/features/search/data/services/search_query_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service Locator for dependency injection
class InjectionContainer {
  factory InjectionContainer() {
    return _instance;
  }

  InjectionContainer._internal();

  static final InjectionContainer _instance = InjectionContainer._internal();

  late TokenStorageService _tokenStorageService;
  late ApiClient _apiClient;
  late ClientMetaService _clientMetaService;
  late IAuthRemoteDataSource _authRemoteDataSource;
  late ISearchRemoteDataSource _searchRemoteDataSource;
  late IPlaylistRemoteDataSource _playlistRemoteDataSource;
  late SearchQueryService _searchQueryService;
  late AuthRepository _authRepository;
  late ConnectivityService _connectivityService;
  late GoogleAuthService _googleAuthService;
  late SocketClient _socketClient;
  late IPlaylistCacheDataSource _playlistCacheDataSource;
  late ITrackRemoteDataSource _trackRemoteDataSource;
  late IEventRemoteDataSource _eventRemoteDataSource;
  late EventRepository _eventRepository;
  late IMusicVoteRemoteDataSource _musicVoteRemoteDataSource;
  late MusicVoteRepository _musicVoteRepository;
  late IProfileRemoteDataSource _profileRemoteDataSource;
  late ProfileRepository _profileRepository;

  /// Initialize all dependencies
  Future<void> init() async {
    // Core Services
    _tokenStorageService = TokenStorageService(
      secureStorage: const FlutterSecureStorage(),
    );
    _searchQueryService = SearchQueryService();
    _googleAuthService = GoogleAuthService();
    final sharedPreferences = await SharedPreferences.getInstance();
    _connectivityService = ConnectivityService();
    _clientMetaService = ClientMetaService(
      sharedPreferences: sharedPreferences,
    );

    // Network
    final dio = Dio();
    _apiClient = ApiClient(
      dio: dio,
      tokenStorage: _tokenStorageService,
      clientMetaService: _clientMetaService,
    );
    _socketClient = SocketClient(
      baseUrl: AppConfig.apiBaseUrl,
      tokenProvider: _tokenStorageService.getToken,
      clientMetaService: _clientMetaService,
    );

    // Data Sources
    _authRemoteDataSource = AuthRemoteDataSource(apiClient: _apiClient);
    _searchRemoteDataSource = SearchRemoteDataSource(apiClient: _apiClient);
    _trackRemoteDataSource = TrackRemoteDataSource(apiClient: _apiClient);
    _eventRemoteDataSource = EventRemoteDataSource(apiClient: _apiClient);
    _musicVoteRemoteDataSource = MusicVoteRemoteDataSource(
      apiClient: _apiClient,
    );
    _playlistRemoteDataSource = PlaylistRemoteDataSource(apiClient: _apiClient);
    _playlistCacheDataSource = PlaylistCacheDataSource(
      preferences: sharedPreferences,
    );
    _profileRemoteDataSource = ProfileRemoteDataSource(apiClient: _apiClient);
    _profileRepository = ProfileRepositoryImpl(
      remoteDataSource: _profileRemoteDataSource,
      eventRemoteDataSource: _eventRemoteDataSource,
      playlistRemoteDataSource: _playlistRemoteDataSource,
    );

    // Repositories
    _authRepository = AuthRepositoryImpl(
      remoteDataSource: _authRemoteDataSource,
      tokenStorage: _tokenStorageService,
      googleAuthService: _googleAuthService,
    );
    _eventRepository = EventRepository(
      remoteDataSource: _eventRemoteDataSource,
    );
    _musicVoteRepository = MusicVoteRepositoryImpl(
      remoteDataSource: _musicVoteRemoteDataSource,
    );
  }

  // Getters
  TokenStorageService get tokenStorageService => _tokenStorageService;
  ApiClient get apiClient => _apiClient;
  ClientMetaService get clientMetaService => _clientMetaService;
  IAuthRemoteDataSource get authRemoteDataSource => _authRemoteDataSource;
  ISearchRemoteDataSource get searchRemoteDataSource => _searchRemoteDataSource;
  IPlaylistRemoteDataSource get playlistRemoteDataSource =>
      _playlistRemoteDataSource;
  SearchQueryService get searchQueryService => _searchQueryService;
  AuthRepository get authRepository => _authRepository;
  ConnectivityService get connectivityService => _connectivityService;
  GoogleAuthService get googleAuthService => _googleAuthService;
  SocketClient get socketClient => _socketClient;
  IPlaylistCacheDataSource get playlistCacheDataSource =>
      _playlistCacheDataSource;
  ITrackRemoteDataSource get trackRemoteDataSource => _trackRemoteDataSource;
  IEventRemoteDataSource get eventRemoteDataSource => _eventRemoteDataSource;
  EventRepository get eventRepository => _eventRepository;
  IMusicVoteRemoteDataSource get musicVoteRemoteDataSource =>
      _musicVoteRemoteDataSource;
  MusicVoteRepository get musicVoteRepository => _musicVoteRepository;
  IProfileRemoteDataSource get profileRemoteDataSource =>
      _profileRemoteDataSource;
  ProfileRepository get profileRepository => _profileRepository;

  AuthBloc createAuthBloc() {
    return AuthBloc(
      authRepository: _authRepository,
      apiClient: _apiClient,
    );
  }

  PlaylistBloc createPlaylistBloc() {
    return PlaylistBloc(
      playlistRemoteDataSource: _playlistRemoteDataSource,
      playlistCacheDataSource: _playlistCacheDataSource,
      connectivityService: _connectivityService,
      socketClient: _socketClient,
    );
  }

  ProfileBloc createProfileBloc() {
    return ProfileBloc(profileRepository: _profileRepository);
  }
}
