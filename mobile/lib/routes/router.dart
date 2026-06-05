import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room/core/widgets/app_scaffold.dart';
import 'package:music_room/features/auth/presentation/pages/enter_new_password_page.dart';
import 'package:music_room/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:music_room/features/auth/presentation/pages/sign_in_page.dart';
import 'package:music_room/features/auth/presentation/pages/sign_up_page.dart';
import 'package:music_room/features/auth/presentation/state/auth_state.dart';
import 'package:music_room/features/events/presentation/pages/create_event_page.dart';
import 'package:music_room/features/home/presentation/pages/home_page.dart';
import 'package:music_room/features/music_vote/presentation/pages/guest_music_vote_page.dart';
import 'package:music_room/features/music_vote/presentation/pages/host_music_vote_page.dart';
import 'package:music_room/features/music_vote/presentation/pages/my_events_page.dart';
import 'package:music_room/features/music_vote/presentation/pages/pre_event_page.dart';
import 'package:music_room/features/playlist/presentation/pages/create_playlist_page.dart';
import 'package:music_room/features/playlist/presentation/pages/playlist_details_page.dart';
import 'package:music_room/features/playlist/presentation/pages/playlist_page.dart';
import 'package:music_room/features/profile/presentation/pages/profile_page.dart';
import 'package:music_room/features/search/presentation/pages/search_page.dart';
import 'package:music_room/features/settings/presentation/pages/email_update_page.dart';
import 'package:music_room/features/settings/presentation/pages/settings_page.dart';
import 'package:music_room/routes/unknown_route_page.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Pending redirect location for auth guard.
/// Set when an unauthenticated user tries to access a protected route.
String? _pendingRedirectLocation;

String? consumePendingRedirect() {
  final value = _pendingRedirectLocation;
  _pendingRedirectLocation = null;
  return value;
}

String? peekPendingRedirect() => _pendingRedirectLocation;

/// Routes that are only accessible to unauthenticated users.
/// Authenticated users will be redirected away from all of these.
const Set<String> _authOnlyRoutes = {
  '/login',
  '/register',
  '/forgot-password',
  '/reset-password',
};

/// Returns true if [location] is an auth-only route (exact path match,
/// ignoring query parameters and trailing slashes).
bool _isAuthOnlyRoute(String location) {
  // Strip query string and normalise trailing slash for a reliable match.
  final path = Uri.parse(location).path.replaceAll(RegExp(r'/$'), '');
  return _authOnlyRoutes.contains(path);
}

GoRouter createRouter(AuthState Function() authStateProvider) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/home',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final authState = authStateProvider();

      // ── 1. Still loading – don't redirect yet ──────────────────────────────
      if (authState is AuthInitial || authState is AuthChecking) {
        return null;
      }

      final location = state.matchedLocation;

      // ── 2. Classify the current auth state ────────────────────────────────
      //
      // |  State               | isFullyAuthenticated | isNewRegistration |
      // |----------------------|----------------------|-------------------|
      // | AuthAuthenticated    | true                 | false             |
      // | LoginSuccess         | true                 | false             |
      // | GoogleLoginSuccess   | true                 | false             |
      // | RegisterSuccess      | false                | true              |
      // | everything else      | false                | false             |
      //
      final isFullyAuthenticated =
          authState is AuthAuthenticated ||
          authState is LoginSuccess ||
          authState is GoogleLoginSuccess;

      final isNewRegistration = authState is RegisterSuccess;

      final isAnyAuthenticated = isFullyAuthenticated || isNewRegistration;

      // ── 3. Unauthenticated user ────────────────────────────────────────────
      if (!isAnyAuthenticated) {
        // Allow auth-only routes through; guard everything else.
        if (!_isAuthOnlyRoute(location)) {
          _pendingRedirectLocation = location;
          return '/login';
        }
        return null; // unauthenticated + auth route → allow
      }

      // ── 4. Fully authenticated user (or newly registered) ──────────────────
      // Block auth-only routes.
      if (_isAuthOnlyRoute(location)) {
        final target = consumePendingRedirect() ?? '/home';
        return target;
      }

      return null; // authenticated + protected route → allow
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const SignInPage(),
        routes: [
          GoRoute(
            path: 'forgot-password',
            builder: (context, state) => const ForgotPasswordPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const SignUpPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) {
          final extra = state.extra as Map<String, String>?;
          final email = extra?['email'] ?? '';
          final resetToken = extra?['resetToken'] ?? '';
          return EnterNewPasswordPage(
            email: email,
            resetToken: resetToken,
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AppScaffold(child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: '/events',
            builder: (context, state) => const MyEventsPage(),
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) => const CreateEventPage(),
              ),
              GoRoute(
                path: ':eventId',
                builder: (context, state) {
                  final eventId = state.pathParameters['eventId']!;
                  return PreEventPage(eventId: eventId);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/playlists',
            builder: (context, state) => const PlaylistPage(),
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) => const CreatePlaylistPage(),
              ),
              GoRoute(
                path: ':playlistId',
                builder: (context, state) {
                  final playlistId = state.pathParameters['playlistId']!;
                  return PlaylistDetailsPage(playlistId: playlistId);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
            routes: [
              GoRoute(
                path: ':userId',
                builder: (context, state) {
                  final userId = state.pathParameters['userId']!;
                  return ProfilePage(userId: userId);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
          GoRoute(
            path: '/email-update',
            builder: (context, state) => const EmailUpdatePage(),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchPage(),
          ),
          GoRoute(
            path: '/music-vote/host/:eventId',
            builder: (context, state) {
              final eventId = state.pathParameters['eventId']!;
              return HostMusicVotePage(eventId: eventId);
            },
          ),
          GoRoute(
            path: '/music-vote/guest/:eventId',
            builder: (context, state) {
              final eventId = state.pathParameters['eventId']!;
              return GuestMusicVotePage(eventId: eventId);
            },
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) {
      return UnknownRoutePage(routeName: state.uri.toString());
    },
  );
}
