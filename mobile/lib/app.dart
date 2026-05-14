import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/services/onboarding_service.dart';
import 'package:music_room/core/services/theme_preference_service.dart';
import 'package:music_room/core/theme/app_theme.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/auth/presentation/state/auth_event.dart';
import 'package:music_room/features/auth/presentation/state/auth_state.dart';
import 'package:music_room/routes/app_router.dart';
import 'package:music_room/routes/route_names.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AuthBloc _authBloc;
  late final ThemePreferenceService _themePreferenceService;

  @override
  void initState() {
    super.initState();
    final container = InjectionContainer();
    _authBloc = container.createAuthBloc();
    _themePreferenceService = container.themePreferenceService;
    _authBloc.add(const AuthStarted());
  }

  @override
  void dispose() {
    unawaited(_authBloc.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>.value(
      value: _authBloc,
      child: AnimatedBuilder(
        animation: _themePreferenceService,
        builder: (context, _) {
          return BlocBuilder<AuthBloc, AuthState>(
            builder: (context, authState) {
              return MaterialApp(
                onGenerateRoute: AppRouter.onGenerateRoute,
                theme: AppTheme.lightTheme(),
                darkTheme: AppTheme.darkTheme(),
                themeMode: _resolveThemeMode(authState),
                home: const _StartupRouteGate(),
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
}

class _StartupRouteGate extends StatefulWidget {
  const _StartupRouteGate();

  @override
  State<_StartupRouteGate> createState() => _StartupRouteGateState();
}

class _StartupRouteGateState extends State<_StartupRouteGate> {
  late final Future<String> _initialRouteFuture;

  @override
  void initState() {
    super.initState();
    _initialRouteFuture = _resolveInitialRoute();
  }

  Future<String> _resolveInitialRoute() async {
    // On web, skip onboarding entirely — users arrive via URL.
    if (!kIsWeb) {
      final hasSeenOnboarding = await OnboardingService().hasSeenOnboarding();
      if (!hasSeenOnboarding) {
        return AppRouter.initialRoute;
      }
    }

    // Check if user is already authenticated
    final tokenStorage = InjectionContainer().tokenStorageService;
    final isAuthenticated = await tokenStorage.isAuthenticated();

    // If authenticated (and onboarded, or web), go directly to home
    if (isAuthenticated) {
      return RouteNames.home;
    }

    // Otherwise show auth page
    return RouteNames.auth;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _initialRouteFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthAuthenticated ||
                state is LoginSuccess ||
                state is RegisterSuccess) {
              unawaited(InjectionContainer().socketClient.reconnectWithAuth());
              // Attach notifications listeners after socket reconnect attempt
              try {
                InjectionContainer().notificationsService
                    .attachSocketListeners();
                // Fetch notifications immediately after login
                unawaited(
                  InjectionContainer().notificationsService
                      .fetchNotifications(),
                );
              } on Exception catch (_) {}
            }

            if (state is LogoutSuccess || state is AuthUnauthenticated) {
              InjectionContainer().socketClient.disconnect();
              try {
                InjectionContainer().notificationsService
                    .detachSocketListeners();
              } on Exception catch (_) {}
              // After logout, navigate back to auth screen
              unawaited(
                Navigator.of(context).pushNamedAndRemoveUntil(
                  RouteNames.auth,
                  (_) => false,
                ),
              );
            }
          },
          child: AppRouter.pageForRoute(snapshot.data!),
        );
      },
    );
  }
}
