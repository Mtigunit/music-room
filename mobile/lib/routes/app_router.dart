import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/app_scaffold.dart';
import 'package:music_room/features/auth/presentation/pages/onboarding_page.dart';
import 'package:music_room/features/auth/presentation/pages/sign_in_page.dart';
import 'package:music_room/features/auth/presentation/pages/sign_up_page.dart';
import 'package:music_room/features/music_control/presentation/pages/music_control_page.dart';
import 'package:music_room/features/music_vote/presentation/pages/host_music_vote_page.dart';
import 'package:music_room/features/music_vote/presentation/pages/pre_event_page.dart';
import 'package:music_room/features/playlist/presentation/pages/playlist_page.dart';
import 'package:music_room/features/profile/presentation/pages/profile_page.dart';
import 'package:music_room/routes/route_names.dart';

class AppRouter {
  static const String initialRoute = RouteNames.onboarding;

  static Widget pageForRoute(String routeName) {
    return _pageForRoute(routeName);
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final routeName = settings.name ?? RouteNames.home;

    final page = _pageForRoute(routeName, arguments: settings.arguments);

    return MaterialPageRoute<void>(
      builder: (_) => page,
      settings: settings,
    );
  }

  static Widget _unknownRoutePage(String routeName) {
    return Scaffold(
      body: Center(
        child: Text('Route not found: $routeName'),
      ),
    );
  }

  static Widget _pageForRoute(String routeName, {Object? arguments}) {
    if (routeName == RouteNames.onboarding) {
      return const OnboardingPage();
    }

    if (routeName == RouteNames.home || routeName == RouteNames.homeAlias) {
      return const AppScaffold();
    }

    if (routeName == RouteNames.auth) {
      return const SignInPage();
    }

    if (routeName == RouteNames.signUp) {
      return const SignUpPage();
    }

    if (routeName == RouteNames.musicVote) {
      return HostMusicVotePage(
        eventId: arguments is String ? arguments : null,
      );
    }

    if (routeName == RouteNames.preEvent) {
      if (arguments is! String || arguments.trim().isEmpty) {
        return _unknownRoutePage('$routeName (missing or invalid eventId)');
      }
      return PreEventPage(
        eventId: arguments,
      );
    }

    if (routeName == RouteNames.playlist) {
      return const PlaylistPage();
    }

    if (routeName == RouteNames.musicControl) {
      return const MusicControlPage();
    }

    if (routeName == RouteNames.profile) {
      return const ProfilePage();
    }

    return _unknownRoutePage(routeName);
  }
}
