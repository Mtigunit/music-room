import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room/core/config/app_config.dart';
import 'package:music_room/core/realtime/socket_events.dart';
import 'package:music_room/core/services/onboarding_service.dart';
import 'package:music_room/core/services/theme_preference_service.dart';
import 'package:music_room/core/theme/app_theme.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/core/widgets/delegation_request_host.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/auth/presentation/pages/onboarding_page.dart';
import 'package:music_room/features/auth/presentation/pages/post_registration_profile_page.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/auth/presentation/state/auth_event.dart';
import 'package:music_room/features/auth/presentation/state/auth_state.dart';
import 'package:music_room/features/subscription/presentation/state/subscription_cubit.dart';
import 'package:music_room/routes/route_names.dart';
import 'package:music_room/routes/router.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AuthBloc _authBloc;
  late final SubscriptionCubit _subscriptionCubit;
  late final ThemePreferenceService _themePreferenceService;
  late final StreamSubscription<String> _rateLimitSubscription;
  StreamSubscription<AuthState>? _authSubscription;
  late final GoRouter _router;
  bool _isLoading = true;
  bool _showOnboarding = false;

  static const Duration _rateLimitSnackbarCooldown = Duration(seconds: 2);
  DateTime? _lastRateLimitSnackbarAt;

  GoRouter _buildRouter() {
    return createRouter(() => _authBloc.state);
  }

  @override
  void initState() {
    super.initState();
    final container = InjectionContainer();
    _authBloc = container.createAuthBloc();
    _subscriptionCubit = SubscriptionCubit(apiClient: container.apiClient);
    _themePreferenceService = container.themePreferenceService;
    _router = _buildRouter();

    _rateLimitSubscription = container.apiClient.rateLimitEvents.listen(
      _showRateLimitMessage,
    );
    container.socketClient.on(
      SocketEvent.exception.value,
      _handleSocketException,
    );

    unawaited(_initializeApp(container));

    _authSubscription = _authBloc.stream.listen((state) {
      if (state is AuthAuthenticated ||
          state is LoginSuccess ||
          state is GoogleLoginSuccess ||
          state is RegisterSuccess) {
        unawaited(_restoreAuthenticatedSession());
        unawaited(_subscriptionCubit.loadSubscription());
        _router.refresh();
      }

      if (state is LogoutSuccess) {
        _subscriptionCubit.reset();
        InjectionContainer().socketClient.disconnect();
        try {
          InjectionContainer().notificationsService.detachSocketListeners();
        } on Exception catch (_) {}
        try {
          InjectionContainer().delegationGateway.detachSocketListeners();
        } on Exception catch (_) {}
      }

      if (state is AuthUnauthenticated || state is LogoutSuccess) {
        _router.refresh();
      }
    });
  }

  Future<void> _initializeApp(InjectionContainer container) async {
    if (!kIsWeb) {
      final hasSeen = await OnboardingService().hasSeenOnboarding();

      if (!hasSeen) {
        await container.tokenStorageService.clearAll();
        if (!mounted) return;
        setState(() {
          _showOnboarding = true;
          _isLoading = false;
        });
        return;
      }
    }

    _authBloc.add(const AuthStarted());

    await _authBloc.stream.firstWhere(
      (state) => state is! AuthInitial && state is! AuthChecking,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _onOnboardingCompleted() async {
    _authBloc.add(const AuthStarted());
    await _authBloc.stream.firstWhere(
      (state) => state is! AuthInitial && state is! AuthChecking,
    );
    if (!mounted) return;
    setState(() {
      _showOnboarding = false;
    });
  }

  void _onPostRegistrationCompleted() {
    _authBloc.add(const OnboardingCompleted());
    final pendingLocation = consumePendingRedirect();
    _router.go(pendingLocation ?? RouteNames.home);
  }

  @override
  void dispose() {
    unawaited(_rateLimitSubscription.cancel());
    InjectionContainer().socketClient.off(
      SocketEvent.exception.value,
      _handleSocketException,
    );
    unawaited(_authSubscription?.cancel());
    unawaited(_subscriptionCubit.close());
    unawaited(_authBloc.close());
    super.dispose();
  }

  Future<void> _restoreAuthenticatedSession() async {
    unawaited(InjectionContainer().socketClient.reconnectWithAuth());

    try {
      InjectionContainer().notificationsService.attachSocketListeners();
      unawaited(InjectionContainer().notificationsService.fetchNotifications());
    } on Exception catch (e, stack) {
      debugPrint('[NotificationsService] attach/fetch failed: $e\n$stack');
    }

    try {
      InjectionContainer().delegationGateway.attachSocketListeners();
    } on Exception catch (e, stack) {
      debugPrint(
        '[DelegationGateway] attachSocketListeners failed: $e\n$stack',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    return BlocProvider<AuthBloc>.value(
      value: _authBloc,
      child: BlocProvider<SubscriptionCubit>.value(
        value: _subscriptionCubit,
        child: AnimatedBuilder(
          animation: _themePreferenceService,
          builder: (context, _) {
            return BlocBuilder<AuthBloc, AuthState>(
              key: ValueKey(_showOnboarding),
              builder: (context, authState) {
                return MaterialApp.router(
                  routerConfig: _router,
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.lightTheme(),
                  darkTheme: AppTheme.darkTheme(),
                  themeMode: _resolveThemeMode(authState),
                  builder: (context, child) {
                    if (_showOnboarding) {
                      return OnboardingPage(
                        onCompleted: _onOnboardingCompleted,
                      );
                    }
                    if (authState is AuthAuthenticated &&
                        authState.showOnboarding) {
                      return PostRegistrationProfilePage(
                        onCompleted: _onPostRegistrationCompleted,
                      );
                    }
                    return DelegationRequestHost(
                      child: child ?? const SizedBox.shrink(),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  ThemeMode _resolveThemeMode(AuthState state) {
    final userId = switch (state) {
      AuthAuthenticated(:final user) => user.id,
      LoginSuccess(:final user) => user.id,
      GoogleLoginSuccess(:final user) => user.id,
      RegisterSuccess(:final user) => user.id,
      _ => null,
    };

    return _themePreferenceService.resolveThemeModeForUser(userId);
  }

  void _showRateLimitMessage(String message) {
    if (!mounted) return;

    final now = DateTime.now();
    final lastShownAt = _lastRateLimitSnackbarAt;
    if (lastShownAt != null &&
        now.difference(lastShownAt) < _rateLimitSnackbarCooldown) {
      return;
    }

    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    _lastRateLimitSnackbarAt = now;
    AppSnackbar.showError(context, message);
  }

  void _handleSocketException(dynamic payload) {
    if (!mounted) return;

    var isRateLimit = false;
    var message = AppConfig.rateLimitMessage;

    if (payload is Map<String, dynamic>) {
      if (payload['event'] == 'rate:limit') {
        isRateLimit = true;
      }
      final msg = payload['message'];
      if (msg is String && msg.isNotEmpty) {
        message = msg;
      }
    }

    if (!isRateLimit) return;

    _showRateLimitMessage(message);
  }
}
