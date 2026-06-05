import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room/core/network/api_rate_limiter.dart';
import 'package:music_room/core/services/onboarding_service.dart';
import 'package:music_room/core/services/theme_preference_service.dart';
import 'package:music_room/core/theme/app_theme.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/core/widgets/delegation_request_host.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/auth/presentation/pages/onboarding_page.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/auth/presentation/state/auth_event.dart';
import 'package:music_room/features/auth/presentation/state/auth_state.dart';
import 'package:music_room/routes/router.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AuthBloc _authBloc;
  late final ThemePreferenceService _themePreferenceService;
  late final StreamSubscription<ApiRateLimitEvent> _rateLimitSubscription;
  late final GoRouter _router;
  bool _isLoading = true;
  bool _showOnboarding = false;

  GoRouter _buildRouter() {
    return createRouter(() => _authBloc.state);
  }

  @override
  void initState() {
    super.initState();
    final container = InjectionContainer();
    _authBloc = container.createAuthBloc();
    _themePreferenceService = container.themePreferenceService;
    _router = _buildRouter();
    _rateLimitSubscription = container.apiClient.rateLimitEvents.listen(
      _handleRateLimitEvent,
    );

    unawaited(_initializeApp(container));

    _authBloc.stream.listen((state) {
      if (state is AuthAuthenticated ||
          state is LoginSuccess ||
          state is GoogleLoginSuccess ||
          state is RegisterSuccess) {
        unawaited(_restoreAuthenticatedSession());
        _router.refresh();
      }

      if (state is LogoutSuccess) {
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

  @override
  void dispose() {
    unawaited(_rateLimitSubscription.cancel());
    unawaited(_authBloc.close());
    super.dispose();
  }

  Future<void> _restoreAuthenticatedSession() async {
    unawaited(InjectionContainer().socketClient.reconnectWithAuth());

    try {
      InjectionContainer().notificationsService.attachSocketListeners();
      unawaited(InjectionContainer().notificationsService.fetchNotifications());
    } on Exception catch (_) {}

    try {
      InjectionContainer().delegationGateway.attachSocketListeners();
    } on Exception catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    return BlocProvider<AuthBloc>.value(
      value: _authBloc,
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
                  return DelegationRequestHost(
                    child: child ?? const SizedBox.shrink(),
                  );
                },
              );
            },
          );
        },
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

  void _handleRateLimitEvent(ApiRateLimitEvent event) {
    if (!mounted || event.delay < const Duration(seconds: 1)) {
      return;
    }

    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      return;
    }

    AppSnackbar.showInfo(context, event.message);
  }
}
