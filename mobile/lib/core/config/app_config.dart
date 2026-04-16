import 'package:flutter/foundation.dart';

class AppConfig {
  // API Configuration
  // Use --dart-define=API_BASE_URL=... to override per environment.
  // Defaults are selected per platform to avoid localhost networking issues.
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
  );

  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) {
      return _apiBaseUrlOverride;
    }
    if (kIsWeb) {
      return 'http://localhost:3000/';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/';
    }
    return 'http://localhost:3000/';
  }
  // static const String apiPrefix = '/api';

  // API Endpoints
  static const String sendOtpEndpoint = 'auth/send-otp';
  static const String verifyOtpEndpoint = 'auth/verify-otp';
  static const String registerEndpoint = 'auth/register';
  static const String loginEndpoint = 'auth/login';
  static const String profileEndpoint = 'auth/profile';

  // Security
  static const String tokenStorageKey = 'auth_token';
  static const String userStorageKey = 'user_profile';

  // Debugging
  static const bool isDebug = kDebugMode;

  // OTP Configuration
  static const int otpLength = 6;
  static const int otpResendTimeoutSeconds = 60;
}
