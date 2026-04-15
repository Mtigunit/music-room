import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/primary_button.dart';
import 'package:music_room/core/widgets/feature_chip.dart';
import 'package:music_room/core/widgets/page_indicator.dart';
import 'package:music_room/features/auth/presentation/widgets/onboarding_slide.dart';
import 'package:music_room/routes/route_names.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onSkip() {
    _pageController.animateToPage(
      2,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onNext() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Reached the end of onboarding
      debugPrint("Navigate to Login");
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(RouteNames.auth);
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
        titleSpacing: 24.0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6.0),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Icon(
                Icons.music_note,
                color: colorScheme.onPrimary,
                size: 20.0,
              ),
            ),
            const SizedBox(width: 8.0),
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
              right: 16.0,
            ), // Total ~24px with default action padding
            child: TextButton(
              onPressed: _onSkip,
              child: Text(
                'Skip',
                style: TextStyle(
                  color:
                      Theme.of(
                        context,
                      ).textTheme.bodyLarge?.color?.withOpacity(0.4) ??
                      Colors.grey,
                  fontWeight: FontWeight.w600,
                  fontSize: 16.0,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 16.0),
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
                      imagePath: 'assets/images/step1.png',
                      title: 'Control the Music Together',
                      subtitle:
                          'Everyone in the room gets a voice. Vote, queue, and vibe together in real time.',
                      indicator: PageIndicator(
                        currentIndex: _currentPage,
                        pageCount: 3,
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
                      imagePath: 'assets/images/step2.png',
                      title: 'Vote & Play in Real-Time',
                      subtitle:
                          'The crowd decides what plays next. Watch the playlist shift live as votes roll in.',
                      indicator: PageIndicator(
                        currentIndex: _currentPage,
                        pageCount: 3,
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
                      imagePath: 'assets/images/step3.png',
                      title: 'Create Your Music Room',
                      subtitle:
                          'Host a room for any occasion — parties, study sessions, or just vibing with friends.',
                      indicator: PageIndicator(
                        currentIndex: _currentPage,
                        pageCount: 3,
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
                padding: const EdgeInsets.only(bottom: 24.0, top: 16.0),
                child: PrimaryButton(
                  text: _currentPage < 2 ? 'Continue' : 'Get Started',
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
