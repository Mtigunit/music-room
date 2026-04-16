import 'package:flutter/material.dart';
import 'package:music_room/core/services/onboarding_service.dart';
import 'package:music_room/core/theme/app_theme.dart';
import 'package:music_room/routes/app_router.dart';
import 'package:music_room/routes/route_names.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateRoute: AppRouter.onGenerateRoute,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      home: const _StartupRouteGate(),
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

    if (hasSeenOnboarding) {
      return RouteNames.auth;
    }

    return AppRouter.initialRoute;
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

        return AppRouter.pageForRoute(snapshot.data!);
      },
    );
  }
}
