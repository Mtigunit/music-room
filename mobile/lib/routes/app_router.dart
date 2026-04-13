import 'package:flutter/material.dart';

import 'package:music_room/routes/route_names.dart';

class AppRouter {
  static const String initialRoute = RouteNames.home;

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      builder: (_) => const SizedBox.shrink(),
      settings: settings,
    );
  }
}
