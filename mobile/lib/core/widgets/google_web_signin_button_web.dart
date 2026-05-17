import 'package:flutter/widgets.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart';
import 'package:music_room/core/services/google_auth_service.dart';

class _GoogleWebSignInButton extends StatefulWidget {
  const _GoogleWebSignInButton();

  @override
  State<_GoogleWebSignInButton> createState() => _GoogleWebSignInButtonState();
}

class _GoogleWebSignInButtonState extends State<_GoogleWebSignInButton> {
  late final Future<void> _initialization = GoogleAuthService().initialize();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(height: 56);
        }

        final platform = GoogleSignInPlatform.instance;
        if (platform is GoogleSignInPlugin) {
          return platform.renderButton();
        }

        return const SizedBox.shrink();
      },
    );
  }
}

Widget googleWebSignInButtonImpl({Key? key}) => const _GoogleWebSignInButton();
