import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/widgets/confirmation_dialog.dart';
import 'package:music_room/core/widgets/responsive_layout.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/auth/presentation/state/auth_event.dart';
import 'package:music_room/features/auth/presentation/state/auth_state.dart';
import 'package:music_room/features/home/presentation/pages/home_page.dart';
import 'package:music_room/features/music_vote/presentation/pages/my_events_page.dart';
import 'package:music_room/features/playlist/presentation/pages/playlist_page.dart';
import 'package:music_room/features/profile/presentation/pages/profile_page.dart';

class AppTabs {
  static const int home = 0;
  static const int events = 1;
  static const int playlist = 2;
  static const int profile = 3;
}

class AppScaffold extends StatefulWidget {
  const AppScaffold({
    super.key,
    this.initialIndex = 0,
  }) : assert(
         initialIndex >= 0 && initialIndex <= 3,
         'initialIndex must be between 0 and 3',
       );
  final int initialIndex;

  @override
  State<AppScaffold> createState() => AppScaffoldState();
}

class AppScaffoldState extends State<AppScaffold> {
  late int _currentIndex;

  final List<Widget> _pages = const [
    HomePage(),
    MyEventsPage(),
    PlaylistPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void switchTab(int index) {
    if (index >= 0 && index < _pages.length) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      builder: (context, size) {
        return switch (size) {
          ScreenSize.compact => _buildWithBottomBar(context),
          ScreenSize.medium => _buildWithRail(context, extended: false),
          ScreenSize.expanded => _buildWithRail(context, extended: true),
        };
      },
    );
  }

  /// Phone: existing BottomNavigationBar — zero visual change.
  Widget _buildWithBottomBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: colorScheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onItemTapped,
          elevation: 0,
          backgroundColor: Colors.transparent,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: colorScheme.onSurface.withValues(alpha: 0.4),
          items: [
            BottomNavigationBarItem(
              icon: StreamBuilder<int>(
                stream:
                    InjectionContainer().notificationsService.unreadCountStream,
                initialData: 0,
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  if (count > 0) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.home_outlined, size: 28),
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: colorScheme.error,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            child: Center(
                              child: Text(
                                count > 99 ? '99+' : count.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return const Icon(Icons.home_outlined, size: 28);
                },
              ),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.sensors, size: 28),
              label: 'Events',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.queue_music, size: 28),
              label: 'Playlist',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline, size: 28),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  /// Tablet / Desktop: NavigationRail on the left side.
  /// [extended] controls whether labels are shown next to icons.
  Widget _buildWithRail(BuildContext context, {required bool extended}) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Row(
        children: [
          // Navigation rail
          Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: _onItemTapped,
              extended: extended,
              minWidth: 72,
              minExtendedWidth: 220,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              selectedIconTheme: IconThemeData(
                color: colorScheme.primary,
                size: 26,
              ),
              unselectedIconTheme: IconThemeData(
                color: colorScheme.onSurface.withValues(alpha: 0.4),
                size: 26,
              ),
              selectedLabelTextStyle: TextStyle(
                color: colorScheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelTextStyle: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              indicatorColor: colorScheme.primary.withValues(alpha: 0.12),
              leading: _buildRailHeader(isDarkMode, extended: extended),
              trailing: _buildRailTrailing(
                context,
                isDarkMode: isDarkMode,
                extended: extended,
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.sensors),
                  selectedIcon: Icon(Icons.sensors),
                  label: Text('Events'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.queue_music),
                  selectedIcon: Icon(Icons.queue_music),
                  label: Text('Playlists'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: Text('Profile'),
                ),
              ],
            ),
          ),

          // Page content
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
          ),
        ],
      ),
    );
  }

  /// Branded header at the top of the NavigationRail.
  /// On tablet (not extended): icon only.
  /// On desktop (extended): icon + app name.
  Widget _buildRailHeader(bool isDarkMode, {required bool extended}) {
    final logoIcon = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.music_note_rounded,
        color: Colors.white,
        size: 20,
      ),
    );

    if (!extended) {
      // Tablet: icon only, centred
      return Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 16),
        child: logoIcon,
      );
    }

    // Desktop: icon + app name
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          logoIcon,
          const SizedBox(width: 12),
          Text(
            'Music Room',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : const Color(0xFF1A1A2E),
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  /// Trailing section at the bottom of the NavigationRail.
  /// Contains dark mode toggle and logout button.
  Widget _buildRailTrailing(
    BuildContext context, {
    required bool isDarkMode,
    required bool extended,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final mutedColor = colorScheme.onSurface.withValues(alpha: 0.5);

    return Expanded(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Divider
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: extended ? 16 : 12,
                  vertical: 8,
                ),
                child: Divider(
                  height: 1,
                  color: colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              ),

              // Dark mode toggle
              _RailActionButton(
                icon: isDarkMode
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                label: isDarkMode ? 'Light Mode' : 'Dark Mode',
                color: mutedColor,
                extended: extended,
                onTap: () => _handleThemeToggle(isDarkMode),
              ),

              const SizedBox(height: 4),

              // Logout
              _RailActionButton(
                icon: Icons.logout_rounded,
                label: 'Log Out',
                color: colorScheme.error,
                extended: extended,
                onTap: () => _handleLogout(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleThemeToggle(bool currentlyDark) async {
    final themeService = InjectionContainer().themePreferenceService;
    final authState = context.read<AuthBloc>().state;

    // Extract userId from the current auth state
    String? userId;
    if (authState is AuthAuthenticated) {
      userId = authState.user.id;
    }

    if (userId == null || userId.isEmpty) {
      return;
    }

    final newPreference = currentlyDark ? 'LIGHT' : 'DARK';
    await themeService.saveThemePreferenceForUser(userId, newPreference);
  }

  Future<void> _handleLogout(BuildContext context) async {
    final authBloc = context.read<AuthBloc>();

    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'Log Out?',
      message: 'Are you sure you want to log out of your account?',
      confirmLabel: 'Log Out',
      icon: Icons.logout_rounded,
      variant: ConfirmationDialogVariant.destructive,
    );

    if (confirmed == true && mounted) {
      authBloc.add(const LogoutRequested());
    }
  }
}

/// A compact action button for the NavigationRail trailing section.
/// Shows icon-only when not extended, icon + label when extended.
class _RailActionButton extends StatelessWidget {
  const _RailActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.extended,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!extended) {
      // Icon-only button for tablet
      return IconButton(
        icon: Icon(icon, color: color, size: 22),
        tooltip: label,
        onPressed: onTap,
      );
    }

    // Full-width button with label for desktop
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
