import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:music_room/app.dart';
import 'package:music_room/di/injection_container.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  try {
    await dotenv.load(fileName: 'assets/.env', isOptional: true);
  } on Exception {
    // If .env is missing, the app will fall back to default configs
    debugPrint('.env file not found, falling back to default URLs');
  }

  // Initialize dependency injection
  await InjectionContainer().init();
  runApp(const App());
}
