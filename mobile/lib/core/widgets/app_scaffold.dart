import 'package:flutter/material.dart';
import 'package:music_room/features/home/presentation/pages/home_page.dart';
import 'package:music_room/features/music_vote/presentation/pages/music_vote_page.dart';
import 'package:music_room/features/playlist/presentation/pages/playlist_page.dart';
import 'package:music_room/features/profile/presentation/pages/profile_page.dart';
import 'package:music_room/features/search/presentation/pages/search_page.dart';

class AppScaffold extends StatefulWidget {
  final int initialIndex;

  const AppScaffold({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  late int _currentIndex;

  final List<Widget> _pages = const [
    HomePage(),
    SearchPage(),
    MusicVotePage(),
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

  @override
  Widget build(BuildContext context) {
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
              width: 1.0,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onItemTapped,
          elevation: 0,
          backgroundColor: Colors.transparent,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedFontSize: 10.0,
          unselectedFontSize: 10.0,
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: colorScheme.onSurface.withValues(alpha: 0.4),
          items: [
            _buildNavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: 'Home',
              index: 0,
            ),
            _buildNavItem(
              icon: Icons.search,
              activeIcon: Icons.search,
              label: 'Search',
              index: 1,
            ),
            _buildNavItem(
              icon: Icons.group_outlined,
              activeIcon: Icons.group,
              label: 'Room',
              index: 2,
            ),
            _buildNavItem(
              icon: Icons.queue_music_outlined,
              activeIcon: Icons.queue_music,
              label: 'Playlist',
              index: 3,
            ),
            _buildNavItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: 'Profile',
              index: 4,
            ),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    final colorScheme = Theme.of(context).colorScheme;

    return BottomNavigationBarItem(
      icon: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isSelected ? activeIcon : icon, size: 28),
          if (isSelected) ...[
            const SizedBox(height: 4),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ] else ...[
            const SizedBox(height: 8), // Replaces dot height to prevent jitter
          ],
        ],
      ),
      label: label,
    );
  }
}
