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
  bool _isReady = false;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    unawaited(_initAndListen());
  }

  Future<void> _initAndListen() async {
    final googleAuthService = InjectionContainer().googleAuthService;
    await googleAuthService.initialize();

    if (!mounted) return;

    _subscription = GoogleSignIn.instance.authenticationEvents.listen((
      event,
    ) async {
      if (!mounted) return;
      if (event is GoogleSignInAuthenticationEventSignIn) {
        final auth = event.user.authentication;
        final idToken = auth.idToken;
        if (idToken != null && idToken.isNotEmpty) {
          await widget.onIdToken(idToken);
        }
      }
    });

    if (mounted) {
      setState(() {
        _isReady = true;
      });
    }
  }

  @override
  void dispose() {
    if (_subscription != null) {
      unawaited(_subscription!.cancel());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const SizedBox(
        width: double.infinity,
        height: 48,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: web.renderButton(),
    );
  }
}
