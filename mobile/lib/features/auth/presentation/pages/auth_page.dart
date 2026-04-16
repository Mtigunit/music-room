import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/app_button.dart';
import 'package:music_room/core/widgets/feature_chip.dart';
import 'package:music_room/core/widgets/primary_button.dart';
import 'package:music_room/features/auth/presentation/pages/sign_in_page.dart';
import 'package:music_room/features/auth/presentation/pages/sign_up_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  Future<void> _showSignUp() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SignUpPage(
          onSwitchToSignIn: () async {
            Navigator.of(context).pop();
            await _showSignIn();
          },
        ),
      ),
    );
  }

  Future<void> _showSignIn() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SignInPage(
          onSwitchToSignUp: () async {
            Navigator.of(context).pop();
            await _showSignUp();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final pageBackground = isDarkMode
        ? const Color(0xFF05070F)
        : Theme.of(context).scaffoldBackgroundColor;
    final bodyTextColor = isDarkMode ? const Color(0xFF757A87) : Colors.black54;
    final legalTextColor = isDarkMode
        ? const Color(0xFF4E5360)
        : Colors.black45;
    final heroOverlayStart = isDarkMode
        ? Colors.black.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.04);
    final heroOverlayMid = isDarkMode
        ? Colors.black.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.38);

    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 58,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/first-step-auth-background.png',
                    fit: BoxFit.cover,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          heroOverlayStart,
                          heroOverlayMid,
                          pageBackground,
                        ],
                        stops: const [0.0, 0.65, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    top: 18,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.music_note,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'MUSIC ROOM',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 52,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 34,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Feel the music ',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(
                                        fontSize: 34,
                                        height: 1.12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                TextSpan(
                                  text: 'together.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(
                                        fontSize: 34,
                                        height: 1.12,
                                        fontWeight: FontWeight.w900,
                                        color: colorScheme.primary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Join live rooms, vote for tracks, and share the '
                            'vibe with people around you - in real time.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: bodyTextColor,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          const SizedBox(height: 24),
                          const Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              FeatureChip(
                                label: 'Live Voting',
                                icon: Icons.how_to_vote_outlined,
                              ),
                              FeatureChip(
                                label: 'Real-time Queue',
                                icon: Icons.queue_music_outlined,
                              ),
                              FeatureChip(
                                label: 'Collaborative',
                                icon: Icons.people_outline,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          PrimaryButton(
                            text: 'Get Started',
                            onPressed: _showSignUp,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: AppButton(
                              variant: AppButtonVariant.outlined,
                              onPressed: _showSignIn,
                              borderRadius: 18,
                              borderSide: BorderSide(
                                color: isDarkMode
                                    ? const Color(0xFF2B3040)
                                    : const Color(0xFFD9DDE8),
                              ),
                              foregroundColor: isDarkMode
                                  ? const Color(0xFF8C90A0)
                                  : const Color(0xFF545B6A),
                              label: 'I already have an account',
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Align(
                            child: Text(
                              'By continuing, you agree to our Terms & '
                              'Privacy Policy',
                              style: TextStyle(
                                color: legalTextColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
