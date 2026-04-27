import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/services/onboarding_service.dart';
import 'package:music_room/core/theme/app_theme.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/auth/presentation/state/auth_event.dart';
import 'package:music_room/features/auth/presentation/state/auth_state.dart';
import 'package:music_room/routes/app_router.dart';
import 'package:music_room/routes/route_names.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>(
      create: (_) =>
          InjectionContainer().createAuthBloc()..add(const AuthStarted()),
      child: MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        theme: AppTheme.lightTheme(),
        darkTheme: AppTheme.darkTheme(),
        home: const _StartupRouteGate(),
      ),
    );
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
    final hasSeenOnboarding = await OnboardingService().hasSeenOnboarding();

    // If user hasn't seen onboarding, show onboarding first
    if (!hasSeenOnboarding) {
      return AppRouter.initialRoute;
    }

    // Check if user is already authenticated
    final tokenStorage = InjectionContainer().tokenStorageService;
    final isAuthenticated = await tokenStorage.isAuthenticated();

    // If authenticated and onboarded, go directly to home
    if (isAuthenticated) {
      return RouteNames.home;
    }

    // If onboarded but not authenticated, show auth page
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
            }

            if (state is LogoutSuccess) {
              InjectionContainer().socketClient.disconnect();
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
