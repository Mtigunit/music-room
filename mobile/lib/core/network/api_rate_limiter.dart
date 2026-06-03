import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

enum ApiRateLimitEventType { delayed, limited }

class ApiRateLimitEvent {
  const ApiRateLimitEvent({
    required this.type,
    required this.message,
    required this.requestKey,
    required this.delay,
  });

  final ApiRateLimitEventType type;
  final String message;
  final String requestKey;
  final Duration delay;
}

class ApiRequestDescriptor {
  ApiRequestDescriptor({
    required String method,
    required String path,
    this.queryParameters,
    this.data,
  }) : method = method.toUpperCase(),
       path = _normalizePath(path),
       requestKey = _buildRequestKey(
         method: method,
         path: path,
         queryParameters: queryParameters,
         data: data,
       );

  final String method;
  final String path;
  final Map<String, dynamic>? queryParameters;
  final Object? data;
  final String requestKey;

  bool get isCoalescable => method == 'GET';

  static String _buildRequestKey({
    required String method,
    required String path,
    Map<String, dynamic>? queryParameters,
    Object? data,
  }) {
    final fingerprint = <String, Object?>{
      'method': method.toUpperCase(),
      'path': _normalizePath(path),
      'queryParameters': _stableEncode(queryParameters),
      'data': _stableEncode(data),
    };

    return sha1.convert(utf8.encode(jsonEncode(fingerprint))).toString();
  }

  static String _normalizePath(String path) {
    final normalizedPath = Uri.parse(path).path.trim();

    if (normalizedPath.isEmpty) {
      return normalizedPath;
    }

    if (normalizedPath.length > 1 && normalizedPath.endsWith('/')) {
      return normalizedPath.substring(0, normalizedPath.length - 1);
    }

    return normalizedPath.startsWith('/')
        ? normalizedPath.substring(1)
        : normalizedPath;
  }

  static Object? _stableEncode(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is FormData) {
      return <String, Object?>{
        'fields': value.fields
            .map(
              (field) => <String, Object?>{
                'key': field.key,
                'value': field.value,
              },
            )
            .toList(growable: false),
        'files': value.files
            .map(
              (file) => <String, Object?>{
                'key': file.key,
                'filename': file.value.filename,
                'contentType': file.value.contentType?.mimeType,
              },
            )
            .toList(growable: false),
      };
    }

    if (value is Map) {
      final sortedEntries = value.entries.toList()
        ..sort(
          (left, right) => left.key.toString().compareTo(right.key.toString()),
        );

      return <String, Object?>{
        for (final entry in sortedEntries)
          entry.key.toString(): _stableEncode(entry.value),
      };
    }

    if (value is Iterable) {
      return value.map(_stableEncode).toList(growable: false);
    }

    return value.toString();
  }
}

class ApiRateLimitRule {
  const ApiRateLimitRule({
    required this.name,
    required this.limit,
    required this.window,
    this.pathPrefix,
    this.exactPath,
  });

  final String name;
  final int limit;
  final Duration window;
  final String? pathPrefix;
  final String? exactPath;

  bool matches(String path) {
    if (pathPrefix != null) {
      return path.startsWith(pathPrefix!);
    }

    if (exactPath != null) {
      return path == exactPath;
    }

    return true;
  }
}

class ApiRateLimiter {
  ApiRateLimiter({
    List<ApiRateLimitRule>? rules,
  }) : _rules =
           rules ??
           const <ApiRateLimitRule>[
             ApiRateLimitRule(
               name: 'auth',
               pathPrefix: 'auth/',
               limit: 10,
               window: Duration(minutes: 1),
             ),
             ApiRateLimitRule(
               name: 'track-search',
               exactPath: 'tracks/search',
               limit: 30,
               window: Duration(minutes: 1),
             ),
             ApiRateLimitRule(
               name: 'global',
               limit: 100,
               window: Duration(minutes: 1),
             ),
           ];

  final List<ApiRateLimitRule> _rules;
  final Queue<_QueuedRequest> _queue = Queue<_QueuedRequest>();
  final Map<String, _QueuedRequest> _coalescedRequests =
      <String, _QueuedRequest>{};
  final Map<String, _RateLimitBucket> _buckets = <String, _RateLimitBucket>{};
  final Map<String, DateTime> _cooldowns = <String, DateTime>{};
  final StreamController<ApiRateLimitEvent> _eventController =
      StreamController<ApiRateLimitEvent>.broadcast();

  Timer? _resumeTimer;
  bool _pumpScheduled = false;
  bool _isPumping = false;
  bool _disposed = false;

  Stream<ApiRateLimitEvent> get events => _eventController.stream;

  Future<T> schedule<T>({
    required ApiRequestDescriptor request,
    required Future<T> Function() execute,
  }) {
    if (_disposed) {
      throw StateError('ApiRateLimiter has been disposed.');
    }

    if (request.isCoalescable) {
      final existing = _coalescedRequests[request.requestKey];
      if (existing != null) {
        return existing.completer.future.then((value) => value as T);
      }
    }

    final pendingRequest = _QueuedRequest(
      request: request,
      execute: () async => (await execute()) as Object?,
    );

    if (request.isCoalescable) {
      _coalescedRequests[request.requestKey] = pendingRequest;
    }

    _queue.addLast(pendingRequest);
    _schedulePump();

    return pendingRequest.completer.future.then((value) => value as T);
  }

  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;
    _resumeTimer?.cancel();
    _resumeTimer = null;
    if (!_eventController.isClosed) {
      unawaited(_eventController.close());
    }
  }

  void _schedulePump() {
    if (_disposed || _pumpScheduled) {
      return;
    }

    _pumpScheduled = true;
    scheduleMicrotask(() {
      _pumpScheduled = false;
      unawaited(_pumpQueue());
    });
  }

  Future<void> _pumpQueue() async {
    if (_disposed || _isPumping) {
      return;
    }

    _isPumping = true;
    try {
      while (_queue.isNotEmpty && !_disposed) {
        final pendingRequest = _queue.first;
        final delay = _delayFor(pendingRequest.request, DateTime.now());

        if (delay > Duration.zero) {
          _emitEvent(
            type: ApiRateLimitEventType.delayed,
            request: pendingRequest.request,
            delay: delay,
            message:
                'Requests are temporarily delayed for '
                '${_formatDuration(delay)} to respect API limits.',
          );
          _resumeTimer?.cancel();
          _resumeTimer = Timer(delay, _schedulePump);
          return;
        }

        _queue.removeFirst();
        _recordHit(pendingRequest.request, DateTime.now());
        unawaited(_runRequest(pendingRequest));
      }
    } finally {
      _isPumping = false;
    }
  }

  Future<void> _runRequest(_QueuedRequest pendingRequest) async {
    try {
      final value = await pendingRequest.execute();
      if (!pendingRequest.completer.isCompleted) {
        pendingRequest.completer.complete(value);
      }
    } on DioException catch (error, stackTrace) {
      if (error.response?.statusCode == 429) {
        final cooldown = _cooldownDurationFor429(
          request: pendingRequest.request,
          response: error.response,
        );
        _applyCooldown(pendingRequest.request, cooldown);
        _emitEvent(
          type: ApiRateLimitEventType.limited,
          request: pendingRequest.request,
          delay: cooldown,
          message:
              'The API rate limit was reached. '
              'Retrying requests will be delayed for '
              '${_formatDuration(cooldown)}.',
        );
      }

      if (!pendingRequest.completer.isCompleted) {
        pendingRequest.completer.completeError(error, stackTrace);
      }
    } catch (error, stackTrace) {
      if (!pendingRequest.completer.isCompleted) {
        pendingRequest.completer.completeError(error, stackTrace);
      }
    } finally {
      if (pendingRequest.request.isCoalescable) {
        _coalescedRequests.remove(pendingRequest.request.requestKey);
      }

      if (_queue.isNotEmpty) {
        _schedulePump();
      }
    }
  }

  Duration _delayFor(ApiRequestDescriptor request, DateTime now) {
    var maxDelay = Duration.zero;

    for (final rule in _matchingRules(request.path)) {
      final bucket = _buckets.putIfAbsent(rule.name, _RateLimitBucket.new)
        ..prune(now, rule.window);

      final cooldownUntil = _cooldowns[rule.name];
      if (cooldownUntil != null && cooldownUntil.isAfter(now)) {
        final cooldownDelay = cooldownUntil.difference(now);
        if (cooldownDelay > maxDelay) {
          maxDelay = cooldownDelay;
        }
      }

      if (bucket.hitCount >= rule.limit) {
        final oldestHit = bucket.hits.first;
        final windowDelay = oldestHit.add(rule.window).difference(now);
        if (windowDelay > maxDelay) {
          maxDelay = windowDelay;
        }
      }
    }

    return maxDelay;
  }

  void _recordHit(ApiRequestDescriptor request, DateTime now) {
    for (final rule in _matchingRules(request.path)) {
      final bucket = _buckets.putIfAbsent(rule.name, _RateLimitBucket.new)
        ..prune(now, rule.window);
      bucket.hits.addLast(now);
    }
  }

  void _applyCooldown(ApiRequestDescriptor request, Duration delay) {
    final cooldownUntil = DateTime.now().add(delay);

    for (final rule in _matchingRules(request.path)) {
      final currentUntil = _cooldowns[rule.name];
      if (currentUntil == null || cooldownUntil.isAfter(currentUntil)) {
        _cooldowns[rule.name] = cooldownUntil;
      }
    }
  }

  Duration _cooldownDurationFor429({
    required ApiRequestDescriptor request,
    required Response<dynamic>? response,
  }) {
    final retryAfter = _parseRetryAfter(response);
    if (retryAfter != null && retryAfter > Duration.zero) {
      return retryAfter;
    }
    final matchingWindows = _matchingRules(
      request.path,
    ).map((rule) => rule.window);
    if (matchingWindows.isEmpty) {
      return const Duration(minutes: 1);
    }
    return matchingWindows.reduce(
      (longest, current) => current > longest ? current : longest,
    );
  }

  Duration? _parseRetryAfter(Response<dynamic>? response) {
    final rawRetryAfter = response?.headers.value('retry-after');
    if (rawRetryAfter == null || rawRetryAfter.trim().isEmpty) {
      return null;
    }

    final seconds = int.tryParse(rawRetryAfter.trim());
    if (seconds == null) {
      return null;
    }

    return Duration(seconds: seconds);
  }

  List<ApiRateLimitRule> _matchingRules(String path) {
    return _rules.where((rule) => rule.matches(path)).toList(growable: false);
  }

  void _emitEvent({
    required ApiRateLimitEventType type,
    required ApiRequestDescriptor request,
    required Duration delay,
    required String message,
  }) {
    if (_eventController.isClosed) {
      return;
    }

    _eventController.add(
      ApiRateLimitEvent(
        type: type,
        message: message,
        requestKey: request.requestKey,
        delay: delay,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes >= 1) {
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds.remainder(60);
      if (seconds == 0) {
        return '$minutes minute${minutes == 1 ? '' : 's'}';
      }

      return '$minutes minute${minutes == 1 ? '' : 's'} '
          '$seconds second${seconds == 1 ? '' : 's'}';
    }

    final seconds = duration.inSeconds;
    if (seconds <= 0) {
      return 'less than a second';
    }

    return '$seconds second${seconds == 1 ? '' : 's'}';
  }
}

class _QueuedRequest {
  _QueuedRequest({
    required this.request,
    required this.execute,
  }) : completer = Completer<Object?>();

  final ApiRequestDescriptor request;
  final Future<Object?> Function() execute;
  final Completer<Object?> completer;
}

class _RateLimitBucket {
  final Queue<DateTime> hits = Queue<DateTime>();

  int get hitCount => hits.length;

  void prune(DateTime now, Duration window) {
    while (hits.isNotEmpty && now.difference(hits.first) >= window) {
      hits.removeFirst();
    }
  }
}
