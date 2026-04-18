import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:music_room/app.dart';
import 'package:music_room/di/injection_container.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load();

  // Initialize dependency injection
  await InjectionContainer().init();
  runApp(const App());
}
