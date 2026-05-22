import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as web;
import 'package:music_room/di/injection_container.dart';

class GoogleWebSignInButton extends StatefulWidget {
  const GoogleWebSignInButton({
    required this.onIdToken,
    super.key,
  });

  final Future<void> Function(String idToken) onIdToken;

  @override
  State<GoogleWebSignInButton> createState() => _GoogleWebSignInButtonState();
}

class _GoogleWebSignInButtonState extends State<GoogleWebSignInButton> {
  bool _isInitializing = false;
  bool _hasInitError = false;
  bool _isSubmitting = false;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    unawaited(_initAndListen());
  }

  Future<void> _initAndListen() async {
    final googleAuthService = InjectionContainer().googleAuthService;
    StreamSubscription<GoogleSignInAuthenticationEvent>? subscription;

    if (mounted) {
      setState(() {
        _isInitializing = true;
        _hasInitError = false;
      });
    }

    await _subscription?.cancel();
    _subscription = null;

    try {
      await googleAuthService.initialize();

      if (!mounted) return;

      subscription = GoogleSignIn.instance.authenticationEvents.listen((
        event,
      ) async {
        if (!mounted) return;
        if (event is GoogleSignInAuthenticationEventSignIn) {
          final auth = event.user.authentication;
          final idToken = auth.idToken;
          if (idToken != null && idToken.isNotEmpty) {
            await _handleIdToken(idToken);
          }
        }
      });

      _subscription = subscription;

      if (mounted) {
        setState(() {
          _hasInitError = false;
          _isInitializing = false;
        });
      }
    } on Exception catch (error, stackTrace) {
      debugPrint(
        '[GoogleWebSignInButton] Initialization failed: $error',
      );
      debugPrintStack(stackTrace: stackTrace);

      await subscription?.cancel();

      if (mounted) {
        setState(() {
          _hasInitError = true;
          _isInitializing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    if (_subscription != null) {
      unawaited(_subscription!.cancel());
    }
    super.dispose();
  }

  Future<void> _handleIdToken(String idToken) async {
    if (_isSubmitting) {
      return;
    }

    if (mounted) {
      setState(() {
        _isSubmitting = true;
      });
    }

    try {
      await widget.onIdToken(idToken);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final borderColor = isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;

    final backgroundColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    final textColor = isDarkMode ? Colors.white : Colors.black87;

    if (_isInitializing) {
      return _buildLoadingState();
    }

    if (_hasInitError) {
      return _buildErrorState();
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 420,
        ),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: Material(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: borderColor,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  IgnorePointer(
                    ignoring: _isSubmitting,
                    child: Opacity(
                      opacity: 0.01,
                      child: SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.fill,
                          child: web.renderButton(),
                        ),
                      ),
                    ),
                  ),

                  // Custom UI overlay
                  IgnorePointer(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _isSubmitting ? 0.7 : 1,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/google_logo.png',
                            width: 22,
                            height: 22,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Continue with Google',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_isSubmitting)
                    Container(
                      decoration: BoxDecoration(
                        color: backgroundColor.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const SizedBox(
      height: 56,
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorState() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDarkMode
        ? Colors.redAccent.shade100
        : Colors.red.shade300;
    final backgroundColor = isDarkMode
        ? const Color(0xFF2A1717)
        : const Color(0xFFFFF6F6);
    final textColor = isDarkMode
        ? Colors.redAccent.shade100
        : Colors.red.shade700;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 420,
        ),
        child: SizedBox(
          width: double.infinity,
          child: Material(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: borderColor,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: textColor,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Google sign-in unavailable',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _initAndListen,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
