import 'package:flutter_test/flutter_test.dart';
import 'package:music_room/features/profile/presentation/pages/settings_page.dart';
import 'package:music_room/routes/app_router.dart';
import 'package:music_room/routes/route_names.dart';

void main() {
  group('AppRouter.resolveStartupRoute', () {
    test('shows onboarding on mobile for first-time users', () {
      expect(
        AppRouter.resolveStartupRoute(
          isWeb: false,
          hasSeenOnboarding: false,
          isAuthenticated: false,
        ),
        RouteNames.onboarding,
      );
    });

    test('routes returning mobile users to auth when not authenticated', () {
      expect(
        AppRouter.resolveStartupRoute(
          isWeb: false,
          hasSeenOnboarding: true,
          isAuthenticated: false,
        ),
        RouteNames.auth,
      );
    });

    test('routes authenticated mobile users to home', () {
      expect(
        AppRouter.resolveStartupRoute(
          isWeb: false,
          hasSeenOnboarding: true,
          isAuthenticated: true,
        ),
        RouteNames.home,
      );
    });

    test('never selects onboarding on web', () {
      expect(
        AppRouter.resolveStartupRoute(
          isWeb: true,
          hasSeenOnboarding: false,
          isAuthenticated: false,
        ),
        RouteNames.auth,
      );
    });

    test('routes authenticated web users to home', () {
      expect(
        AppRouter.resolveStartupRoute(
          isWeb: true,
          hasSeenOnboarding: false,
          isAuthenticated: true,
        ),
        RouteNames.home,
      );
    });
  });

  group('AppRouter.pageForRoute', () {
    test('maps settings route to SettingsPage', () {
      expect(
        AppRouter.pageForRoute(RouteNames.settings),
        isA<SettingsPage>(),
      );
    });
  });
}
