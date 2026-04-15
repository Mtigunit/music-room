import 'package:flutter/material.dart';
import 'package:music_room/core/theme/app_theme.dart';
import 'package:music_room/routes/app_router.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: AppRouter.initialRoute,
      onGenerateRoute: AppRouter.onGenerateRoute,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
    );
  }
}
