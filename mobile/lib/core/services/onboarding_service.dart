import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const String _onboardingSeenKey = 'onboarding_seen';

  Future<bool> hasSeenOnboarding() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_onboardingSeenKey) ?? false;
  }

  Future<void> markOnboardingSeen() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_onboardingSeenKey, true);
  }
}
