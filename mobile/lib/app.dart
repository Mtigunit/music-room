import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/services/onboarding_service.dart';
import 'package:music_room/core/services/theme_preference_service.dart';
import 'package:music_room/core/theme/app_theme.dart';
import 'package:music_room/core/widgets/animated_splash_screen.dart';
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
  bool _splashCompleted = false;
  String? _resolvedRoute;

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

  void _navigateToInitialRoute(String route) {
    if (!mounted) return;
    unawaited(Navigator.of(context).pushReplacementNamed(route));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _initialRouteFuture,
      builder: (context, snapshot) {
        // Store resolved route when available
        if (snapshot.hasData && _resolvedRoute == null) {
          _resolvedRoute = snapshot.data;
        }

        // On web, skip splash screen and go directly to route
        if (kIsWeb) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          // Navigate immediately on web
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_splashCompleted) {
              _splashCompleted = true;
              _navigateToInitialRoute(snapshot.data!);
            }
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Mobile: Show animated splash screen
        if (!snapshot.hasData) {
          return AnimatedSplashScreen(
            onComplete: () {
              if (!_splashCompleted) {
                _splashCompleted = true;
                // Wait for route to be resolved if not yet available
                if (_resolvedRoute != null) {
                  _navigateToInitialRoute(_resolvedRoute!);
                } else {
                  // Route will be available soon, handle completion
                  unawaited(
                    _initialRouteFuture.then((route) {
                      if (mounted && !_splashCompleted) {
                        _navigateToInitialRoute(route);
                      }
                    }),
                  );
                }
              }
            },
          );
        }

        // Once we have the route, show splash with navigation queued
        // (mobile only)
        return AnimatedSplashScreen(
          onComplete: () {
            if (!_splashCompleted) {
              _splashCompleted = true;
              _navigateToInitialRoute(snapshot.data!);
            }
          },
        );
      },
    );
  }
}
