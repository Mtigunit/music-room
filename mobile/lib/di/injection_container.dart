import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:music_room/core/network/api_client.dart';
import 'package:music_room/core/services/token_storage_service.dart';
import 'package:music_room/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:music_room/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:music_room/features/auth/domain/repositories/auth_repository.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/events/data/datasources/track_remote_datasource.dart';
import 'package:music_room/features/search/data/datasources/search_remote_datasource.dart';
import 'package:music_room/features/search/data/services/search_query_service.dart';

/// Service Locator for dependency injection
class InjectionContainer {
  factory InjectionContainer() {
    return _instance;
  }

  InjectionContainer._internal();

  static final InjectionContainer _instance = InjectionContainer._internal();

  late TokenStorageService _tokenStorageService;
  late ApiClient _apiClient;
  late IAuthRemoteDataSource _authRemoteDataSource;
  late ISearchRemoteDataSource _searchRemoteDataSource;
  late SearchQueryService _searchQueryService;
  late AuthRepository _authRepository;
  late ITrackRemoteDataSource _trackRemoteDataSource;

  /// Initialize all dependencies
  Future<void> init() async {
    // Core Services
    _tokenStorageService = TokenStorageService(
      secureStorage: const FlutterSecureStorage(),
    );
    _searchQueryService = SearchQueryService();

    // Network
    final dio = Dio();
    _apiClient = ApiClient(
      dio: dio,
      tokenStorage: _tokenStorageService,
    );

    // Data Sources
    _authRemoteDataSource = AuthRemoteDataSource(apiClient: _apiClient);
    _searchRemoteDataSource = SearchRemoteDataSource(apiClient: _apiClient);
    _trackRemoteDataSource = TrackRemoteDataSource(apiClient: _apiClient);

    // Repositories
    _authRepository = AuthRepositoryImpl(
      remoteDataSource: _authRemoteDataSource,
      tokenStorage: _tokenStorageService,
    );
  }

  // Getters
  TokenStorageService get tokenStorageService => _tokenStorageService;
  ApiClient get apiClient => _apiClient;
  IAuthRemoteDataSource get authRemoteDataSource => _authRemoteDataSource;
  ISearchRemoteDataSource get searchRemoteDataSource => _searchRemoteDataSource;
  SearchQueryService get searchQueryService => _searchQueryService;
  AuthRepository get authRepository => _authRepository;
  ITrackRemoteDataSource get trackRemoteDataSource => _trackRemoteDataSource;

  AuthBloc createAuthBloc() {
    return AuthBloc(authRepository: _authRepository);
  }
}
