import 'package:flutter/widgets.dart';

import 'package:music_room/core/widgets/google_web_signin_button_stub.dart'
    if (dart.library.html) 'package:music_room/core/widgets/google_web_signin_button_web.dart';

Widget googleWebSignInButton({Key? key}) => googleWebSignInButtonImpl(key: key);
