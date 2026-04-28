import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum GoogleAuthErrorType {
  cancelled,
  missingIdToken,
  network,
  unknown,
}

class GoogleAuthException implements Exception {
  const GoogleAuthException({
    required this.type,
    required this.message,
  });

  final GoogleAuthErrorType type;
  final String message;

  @override
  String toString() => message;
}

class GoogleAuthTokens {
  const GoogleAuthTokens({
    required this.idToken,
    this.accessToken,
  });

  final String idToken;
  final String? accessToken;
}

class GoogleAuthService {
  GoogleAuthService({GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final GoogleSignIn _googleSignIn;

  static String get _webClientId => dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';

  Future<void>? _initialization;

  Future<void> initialize() {
    if (_initialization == null) {
      if (_webClientId.isEmpty) {
        _initialization = _googleSignIn.initialize();
      } else {
        _initialization = _googleSignIn.initialize(
          serverClientId: _webClientId,
        );
      }
    }

    return _initialization!;
  }

  Future<GoogleAuthTokens> authenticate() async {
    await initialize();

    try {
      final account = await _googleSignIn.authenticate();

      // `authenticate()` returns a non-null account when successful.

      final auth = account.authentication;
      final idToken = auth.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw const GoogleAuthException(
          type: GoogleAuthErrorType.missingIdToken,
          message:
              'Google sign-in did not return an ID token. '
              'Check OAuth client configuration.',
        );
      }

      return GoogleAuthTokens(
        idToken: idToken,
      );
    } on GoogleAuthException {
      rethrow;
    } on Exception catch (e) {
      final errorText = e.toString().toLowerCase();

      if (errorText.contains('cancel') || errorText.contains('canceled')) {
        throw const GoogleAuthException(
          type: GoogleAuthErrorType.cancelled,
          message: 'Google sign-in was cancelled.',
        );
      }

      if (errorText.contains('network') ||
          errorText.contains('socket') ||
          errorText.contains('connection')) {
        throw const GoogleAuthException(
          type: GoogleAuthErrorType.network,
          message:
              'Google sign-in failed due to a network issue. '
              'Please check your connection.',
        );
      }

      throw GoogleAuthException(
        type: GoogleAuthErrorType.unknown,
        message: 'Google sign-in failed: $e',
      );
    }
  }

  Future<void> signOut() async {
    await initialize();
    await _googleSignIn.signOut();
  }
}
