import 'dart:async';
import 'package:flutter/material.dart';
import 'package:music_room/core/services/onboarding_service.dart';
import 'package:music_room/core/widgets/app_button.dart';
import 'package:music_room/core/widgets/feature_chip.dart';
import 'package:music_room/core/widgets/page_indicator.dart';
import 'package:music_room/core/widgets/primary_button.dart';
import 'package:music_room/features/auth/presentation/widgets/onboarding_slide.dart';
import 'package:music_room/routes/route_names.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final OnboardingService _onboardingService = OnboardingService();
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int pageCount = 3;
  final int lastIndex = pageCount - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboardingAndExit() async {
    await _onboardingService.markOnboardingSeen();

    if (!mounted) {
      return;
    }

    unawaited(Navigator.of(context).pushReplacementNamed(RouteNames.auth));
  }

  void _onSkip() {
    unawaited(_completeOnboardingAndExit());
  }

  void _onNext() {
    if (_currentPage < lastIndex) {
      unawaited(
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ),
      );
    } else {
      unawaited(_completeOnboardingAndExit());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        titleSpacing: 24,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.music_note,
                color: colorScheme.onPrimary,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Music Room',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(
              right: 16,
            ), // Total ~24px with default action padding
            child: AppButton(
              variant: AppButtonVariant.text,
              onPressed: _onSkip,
              label: 'Skip',
              foregroundColor:
                  Theme.of(context).textTheme.bodyLarge?.color?.withValues(
                    alpha: 0.4,
                  ) ??
                  Colors.grey,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  children: [
                    OnboardingSlide(
                      imagePath: 'assets/images/step1.webp',
                      title: 'Control the Music Together',
                      subtitle:
                          'Everyone in the room gets a voice. Vote, queue, '
                          'and vibe together in real time.',
                      indicator: PageIndicator(
                        currentIndex: _currentPage,
                      ),
                      chips: const [
                        FeatureChip(
                          label: 'Shared Queue',
                          icon: Icons.people_outline,
                        ),
                        FeatureChip(
                          label: 'Real-Time Sync',
                          icon: Icons.wifi_tethering,
                        ),
                      ],
                    ),
                    OnboardingSlide(
                      imagePath: 'assets/images/step2.webp',
                      title: 'Vote & Play in Real-Time',
                      subtitle:
                          'The crowd decides what plays next. '
                          'Watch the playlist shift live as votes roll in.',
                      indicator: PageIndicator(
                        currentIndex: _currentPage,
                      ),
                      chips: const [
                        FeatureChip(
                          label: 'Upvote Tracks',
                          icon: Icons.thumb_up_outlined,
                        ),
                        FeatureChip(
                          label: 'Live Rankings',
                          icon: Icons.bar_chart,
                        ),
                      ],
                    ),
                    OnboardingSlide(
                      imagePath: 'assets/images/step3.webp',
                      title: 'Create Your Music Room',
                      subtitle:
                          'Host a room for any occasion — parties, '
                          'study sessions, or just vibing with friends.',
                      indicator: PageIndicator(
                        currentIndex: _currentPage,
                      ),
                      chips: const [
                        FeatureChip(
                          label: 'Private Rooms',
                          icon: Icons.lock_outline,
                        ),
                        FeatureChip(
                          label: 'Invite Friends',
                          icon: Icons.person_add_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 24, top: 16),
                child: PrimaryButton(
                  text: _currentPage < lastIndex ? 'Continue' : 'Get Started',
                  icon: Icons.arrow_forward,
                  onPressed: _onNext,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
