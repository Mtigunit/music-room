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
