import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // API Configuration
  // Use .env file or --dart-define=API_BASE_URL=... to override
  // Defaults are selected per platform to avoid localhost networking issues.
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
  );

  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) {
      return _apiBaseUrlOverride;
    }

    if (kIsWeb) {
      return dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000/';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:3000/';
    }
    return dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000/';
  }

  // API Endpoints
  static const String sendOtpEndpoint = 'auth/send-otp';
  static const String verifyOtpEndpoint = 'auth/verify-otp';
  static const String forgotPasswordEndpoint = 'auth/forgot-password';
  static const String verifyResetOtpEndpoint = 'auth/verify-reset-otp';
  static const String resetPasswordEndpoint = 'auth/reset-password';
  static const String registerEndpoint = 'auth/register';
  static const String loginEndpoint = 'auth/login';
  static const String googleAuthEndpoint = 'auth/google';
  static const String profileEndpoint = 'auth/profile';
  static const String myProfileEndpoint = 'users/me';
  static const String userDetailEndpoint = 'users';
  static const String linkGoogleAccountEndpoint = 'users/link-google';

  static const String searchUsersEndpoint = 'users/search';

  // Email update endpoints (two-phase flow)
  static const String requestEmailUpdateEndpoint = 'users/me/email/request';
  static const String verifyEmailUpdateEndpoint = 'users/me/email/verify';
  static const String trackSearchEndpoint = 'tracks/search';
  static const String eventsEndpoint = 'events';
  static const String eventsExploreEndpoint = 'events/explore';
  static const String eventsFriendsEndpoint = 'events/friends';
  static const String eventsInvitedEndpoint = 'events/invited';
  static const String eventsHostingEndpoint = 'events/hosting';
  static const String playlistsEndpoint = 'playlists';
  static const String explorePlaylistsEndpoint = 'playlists/explore';
  static const String websocketPath = '/ws';

  // Track Endpoints
  static const String searchTracksEndpoint = trackSearchEndpoint;

  // Security
  static const String tokenStorageKey = 'auth_token';

  /// Security: Allow unencrypted storage fallback on Web (LocalStorage/SharedPreferences).
  /// This is required for HTTP environments but should be false for HTTPS
  /// production.
  static const bool allowInsecureStorage = true;
  static const String userStorageKey = 'user_profile';
  static const int stalePlaylistThresholdHours = 24;

  // Debugging
  static const bool isDebug = kDebugMode;

  // OTP Configuration
  static const int otpLength = 6;
  static const int otpResendTimeoutSeconds = 60;
}
