import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:music_room/core/config/app_config.dart';
import 'package:music_room/core/services/token_storage_service.dart';

class ApiClient {
  ApiClient({
    required Dio dio,
    required TokenStorageService tokenStorage,
  }) : _dio = dio,
       _tokenStorage = tokenStorage {
    _setupInterceptors();
  }

  final Dio _dio;
  final TokenStorageService _tokenStorage;

  void _setupInterceptors() {
    _dio.options.baseUrl = AppConfig.apiBaseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);

    // JWT Token Interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          options.headers['Content-Type'] = 'application/json';
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Handle 401 Unauthorized (token expired)
          if (error.response?.statusCode == 401) {
            await _tokenStorage.clearToken();
          }

          if (AppConfig.isDebug) {
            final method = error.requestOptions.method;
            final uri = error.requestOptions.uri;
            final statusCode = error.response?.statusCode;
            final rootError = error.error;
            debugPrint(
              '[DioError] $method $uri | type=${error.type} '
              '| status=$statusCode | error=$rootError',
            );
          }

          return handler.next(error);
        },
      ),
    );
  }

  // GET Request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // POST Request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // PUT Request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // DELETE Request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }
}
