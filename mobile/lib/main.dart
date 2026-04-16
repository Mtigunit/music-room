import 'package:flutter/widgets.dart';
import 'package:music_room/app.dart';
import 'package:music_room/di/injection_container.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize dependency injection
  await InjectionContainer().init();
  runApp(const App());
}
