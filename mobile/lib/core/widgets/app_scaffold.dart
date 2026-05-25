import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/services/notifications_service.dart';
import 'package:music_room/core/widgets/app_brand_icon.dart';
import 'package:music_room/core/widgets/confirmation_dialog.dart';
import 'package:music_room/core/widgets/responsive_layout.dart';
import 'package:music_room/core/widgets/sidebar_constants.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/auth/presentation/state/auth_event.dart';
import 'package:music_room/features/auth/presentation/state/auth_state.dart';
import 'package:music_room/features/home/presentation/pages/home_page.dart';
import 'package:music_room/features/music_vote/presentation/pages/my_events_page.dart';
import 'package:music_room/features/playlist/presentation/pages/playlist_page.dart';
import 'package:music_room/features/profile/domain/entities/profile_entity.dart';
import 'package:music_room/features/profile/presentation/pages/profile_page.dart';
import 'package:music_room/features/profile/presentation/pages/settings_page.dart';
import 'package:music_room/routes/route_names.dart';

// =============================================================================
// NAVIGATION ITEM METADATA
// =============================================================================

class _NavItemData {
  const _NavItemData({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.tabIndex,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int tabIndex;
}

const List<_NavItemData> _navItems = [
  _NavItemData(
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    tabIndex: AppTabs.home,
  ),
  _NavItemData(
    label: 'Events',
    icon: Icons.sensors,
    selectedIcon: Icons.sensors,
    tabIndex: AppTabs.events,
  ),
  _NavItemData(
    label: 'Playlists',
    icon: Icons.queue_music_outlined,
    selectedIcon: Icons.queue_music_rounded,
    tabIndex: AppTabs.playlist,
  ),
  _NavItemData(
    label: 'Profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    tabIndex: AppTabs.profile,
  ),
];

// =============================================================================
// APP SCAFFOLD
// =============================================================================

class AppScaffold extends StatefulWidget {
  const AppScaffold({
    super.key,
    this.initialIndex = 0,
    this.foregroundPage,
  }) : assert(
         initialIndex >= 0 && initialIndex <= 3,
         'initialIndex must be between 0 and 3',
       );

  final int initialIndex;

  /// When set, this page is shown instead of the tab stack. Navigation taps
  /// that change the current tab will push a replacement [AppScaffold].
  final Widget? foregroundPage;

  @override
  State<AppScaffold> createState() => AppScaffoldState();
}

class AppScaffoldState extends State<AppScaffold> {
  late int _currentIndex;
  late final GlobalKey<ProfilePageState> _profilePageKey;
  late final List<Widget> _pages;

  bool get _hasForegroundPage => widget.foregroundPage != null;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _profilePageKey = GlobalKey<ProfilePageState>();
    _pages = [
      const HomePage(),
      const MyEventsPage(),
      const PlaylistPage(),
      ProfilePage(key: _profilePageKey),
    ];
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _onItemTapped(int index) {
    if (_hasForegroundPage) {
      // Foreground page is active: only navigate if the tab actually changes.
      if (index == _currentIndex) return;
      unawaited(
        Navigator.of(context).pushReplacement<void, void>(
          MaterialPageRoute<void>(
            builder: (_) => AppScaffold(initialIndex: index),
          ),
        ),
      );
      return;
    }

    setState(() => _currentIndex = index);
  }

  /// Programmatically switch to [index] without the foreground-page guard.
  void switchTab(int index) {
    if (index >= 0 && index < _pages.length) {
      setState(() => _currentIndex = index);
    }
  }

  Future<void> _openSettings(BuildContext context) async {
    ProfileUpdateRequest? request;

    final navigator = Navigator.of(context);

    try {
      final result = await navigator.pushNamed(RouteNames.settings);
      request = result is ProfileUpdateRequest ? result : null;
    } on Exception catch (_) {
      request = await navigator.push<ProfileUpdateRequest>(
        MaterialPageRoute<ProfileUpdateRequest>(
          builder: (_) => const SettingsPage(),
        ),
      );
    }

    if (request == null) {
      return;
    }

    _profilePageKey.currentState?.submitProfileUpdate(request);
  }

  // ---------------------------------------------------------------------------
  // Body
  // ---------------------------------------------------------------------------

  Widget _buildBodyContent() {
    if (_hasForegroundPage) return widget.foregroundPage!;

    return IndexedStack(
      index: _currentIndex,
      children: _pages,
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      builder: (context, size) => switch (size) {
        ScreenSize.compact => _buildWithBottomBar(context),
        ScreenSize.medium => _buildWithRail(context, extended: false),
        ScreenSize.expanded => _buildWithRail(context, extended: true),
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Phone layout – BottomNavigationBar
  // ---------------------------------------------------------------------------

  Widget _buildWithBottomBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final notificationsService = InjectionContainer().notificationsService;

    return Scaffold(
      body: _buildBodyContent(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: colorScheme.onSurface.withValues(
                alpha: kBottomNavBorderAlpha,
              ),
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
          unselectedItemColor: colorScheme.onSurface.withValues(
            alpha: kBottomNavUnselectedAlpha,
          ),
          items: [
            // Home tab gets a live unread-count badge; all others are static.
            BottomNavigationBarItem(
              icon: _HomeTabIcon(
                notificationsService: notificationsService,
                badgeColor: colorScheme.error,
              ),
              label: _navItems[AppTabs.home].label,
            ),
            for (final item in _navItems.skip(1))
              BottomNavigationBarItem(
                icon: Icon(item.icon, size: kBottomNavIconSize),
                label: item.label,
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tablet / Desktop layout – custom sidebar rail
  // ---------------------------------------------------------------------------

  Widget _buildWithRail(BuildContext context, {required bool extended}) {
    final colorScheme = Theme.of(context).colorScheme;
    final sidebarColors = _SidebarThemeTokens.fromColorScheme(colorScheme);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            extended: extended,
            colors: sidebarColors,
            isDarkMode: isDarkMode,
            currentIndex: _currentIndex,
            navItems: _navItems,
            onNavItemTap: _onItemTapped,
            onThemeToggle: () => _handleThemeToggle(isDarkMode),
            onSettingsTap: () => unawaited(_openSettings(context)),
            onLogoutTap: () => _handleLogout(context),
          ),
          Expanded(child: _buildBodyContent()),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _handleThemeToggle(bool currentlyDark) async {
    final themeService = InjectionContainer().themePreferenceService;
    final authState = context.read<AuthBloc>().state;

    final userId = authState is AuthAuthenticated ? authState.user.id : null;
    if (userId == null || userId.isEmpty) return;

    final newPreference = currentlyDark
        ? kThemePreferenceLight
        : kThemePreferenceDark;
    await themeService.saveThemePreferenceForUser(userId, newPreference);
  }

  Future<void> _handleLogout(BuildContext context) async {
    final authBloc = context.read<AuthBloc>();

    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: kLogoutDialogTitle,
      message: kLogoutDialogMessage,
      confirmLabel: kLogoutDialogConfirmLabel,
      icon: Icons.logout_rounded,
      variant: ConfirmationDialogVariant.destructive,
    );

    if (confirmed == true && mounted) {
      authBloc.add(const LogoutRequested());
    }
  }
}

// =============================================================================
// _HomeTabIcon — live-updating badge for the Home bottom-nav item
// =============================================================================

class _HomeTabIcon extends StatelessWidget {
  const _HomeTabIcon({
    required this.notificationsService,
    required this.badgeColor,
  });

  final NotificationsService notificationsService;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: notificationsService.unreadCountStream,
      initialData: notificationsService.unreadCount,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count <= 0) {
          return const Icon(Icons.home_outlined, size: kBottomNavIconSize);
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.home_outlined, size: kBottomNavIconSize),
            Positioned(
              right: kBadgeRightOffset,
              top: kBadgeTopOffset,
              child: _NotificationBadge(count: count, color: badgeColor),
            ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// _NotificationBadge
// =============================================================================

class _NotificationBadge extends StatelessWidget {
  const _NotificationBadge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(kBadgePadding),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      constraints: const BoxConstraints(
        minWidth: kBadgeMinSize,
        minHeight: kBadgeMinSize,
      ),
      child: Center(
        child: Text(
          count > kMaxBadgeCount ? '$kMaxBadgeCount+' : count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: kBadgeFontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _Sidebar — full left-side navigation panel for tablet / desktop
// =============================================================================

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.extended,
    required this.colors,
    required this.isDarkMode,
    required this.currentIndex,
    required this.navItems,
    required this.onNavItemTap,
    required this.onThemeToggle,
    required this.onSettingsTap,
    required this.onLogoutTap,
  });

  final bool extended;
  final _SidebarThemeTokens colors;
  final bool isDarkMode;
  final int currentIndex;
  final List<_NavItemData> navItems;
  final ValueChanged<int> onNavItemTap;
  final VoidCallback onThemeToggle;
  final VoidCallback onSettingsTap;
  final VoidCallback onLogoutTap;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = extended
        ? kSidebarExtendedPadding
        : kSidebarCollapsedPadding;

    return Container(
      width: extended ? kSidebarExtendedWidth : kSidebarCollapsedWidth,
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(right: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            kSidebarTopPadding,
            horizontalPadding,
            kSidebarBottomPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SidebarHeader(extended: extended, colors: colors),
              SizedBox(
                height: extended
                    ? kSidebarHeaderGapExtended
                    : kSidebarHeaderGapCollapsed,
              ),
              ..._buildNavItems(),
              const Spacer(),
              Divider(
                height: 1,
                color: colors.border.withValues(
                  alpha: kBorderAlpha,
                ),
              ),
              SizedBox(
                height: extended
                    ? kSidebarUtilityGapExtended
                    : kSidebarUtilityGapCollapsed,
              ),
              ..._buildUtilityButtons(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildNavItems() {
    return [
      for (final item in navItems) ...[
        _SidebarNavItem(
          extended: extended,
          colors: colors,
          label: item.label,
          icon: currentIndex == item.tabIndex ? item.selectedIcon : item.icon,
          isSelected: currentIndex == item.tabIndex,
          onTap: () => onNavItemTap(item.tabIndex),
        ),
        const SizedBox(height: kSidebarNavItemGap),
      ],
    ];
  }

  List<Widget> _buildUtilityButtons() {
    return [
      _SidebarUtilityButton(
        extended: extended,
        colors: colors,
        icon: isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        label: isDarkMode ? 'Light Mode' : 'Dark Mode',
        onTap: onThemeToggle,
      ),
      const SizedBox(height: kSidebarUtilityButtonGap),
      _SidebarUtilityButton(
        extended: extended,
        colors: colors,
        icon: Icons.settings_outlined,
        label: 'Settings',
        onTap: onSettingsTap,
      ),
      const SizedBox(height: kSidebarUtilityButtonGap),
      _SidebarUtilityButton(
        extended: extended,
        colors: colors,
        icon: Icons.logout_rounded,
        label: 'Logout',
        foregroundColor: colors.dangerForeground,
        onTap: onLogoutTap,
      ),
    ];
  }
}

// =============================================================================
// _SidebarHeader
// =============================================================================

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({required this.extended, required this.colors});

  final bool extended;
  final _SidebarThemeTokens colors;

  @override
  Widget build(BuildContext context) {
    final avatarSize = extended ? kAvatarSizeExtended : kAvatarSizeCollapsed;
    final iconSize = extended
        ? kBrandIconSizeExtended
        : kBrandIconSizeCollapsed;

    final avatar = Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        color: colors.avatarBackground,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: AppBrandIcon(size: iconSize, color: colors.brandIcon),
      ),
    );

    if (!extended) return Center(child: avatar);

    return Row(
      children: [
        avatar,
        const SizedBox(width: kHeaderAvatarTextGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kProfileDisplayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.title,
                  fontSize: kHeaderTitleFontSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: kHeaderTitleLetterSpacing,
                  height: kHeaderTitleLineHeight,
                ),
              ),
              const SizedBox(height: kHeaderTitleSubtitleGap),
              Text(
                kProfileSubtitle,
                style: TextStyle(
                  color: colors.subtitle,
                  fontSize: kHeaderSubtitleFontSize,
                  fontWeight: FontWeight.w500,
                  letterSpacing: kHeaderSubtitleLetterSpacing,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// _SidebarNavItem
// =============================================================================

class _SidebarNavItem extends StatelessWidget {
  const _SidebarNavItem({
    required this.extended,
    required this.colors,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final bool extended;
  final _SidebarThemeTokens colors;
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = isSelected
        ? colors.selectedForeground
        : colors.unselectedForeground;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kNavItemBorderRadius),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kNavItemBorderRadius),
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      colors.activeGradientStart,
                      colors.activeGradientEnd,
                    ],
                  )
                : null,
          ),
          child: SizedBox(
            height: kNavItemHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: extended ? kNavItemHorizontalPaddingExtended : 0,
              ),
              child: Row(
                mainAxisAlignment: extended
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  Icon(icon, color: foregroundColor, size: kNavItemIconSize),
                  if (extended) ...[
                    const SizedBox(width: kNavItemIconLabelGap),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: foregroundColor,
                          fontSize: kNavItemFontSize,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          letterSpacing: kNavItemLetterSpacing,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _SidebarUtilityButton
// =============================================================================

class _SidebarUtilityButton extends StatelessWidget {
  const _SidebarUtilityButton({
    required this.extended,
    required this.colors,
    required this.icon,
    required this.label,
    required this.onTap,
    this.foregroundColor,
  });

  final bool extended;
  final _SidebarThemeTokens colors;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Override to use a colour other than
  /// [_SidebarThemeTokens.unselectedForeground].
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final effectiveForeground = foregroundColor ?? colors.unselectedForeground;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kUtilityButtonBorderRadius),
        onTap: onTap,
        child: SizedBox(
          height: kUtilityButtonHeight,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: extended
                  ? kUtilityButtonHorizontalPaddingExtended
                  : 0,
            ),
            child: Row(
              mainAxisAlignment: extended
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: effectiveForeground,
                  size: kUtilityButtonIconSize,
                ),
                if (extended) ...[
                  const SizedBox(width: kUtilityButtonIconLabelGap),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: effectiveForeground,
                        fontSize: kUtilityButtonFontSize,
                        fontWeight: FontWeight.w600,
                        letterSpacing: kUtilityButtonLetterSpacing,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _SidebarThemeTokens — resolved colours for one brightness
// =============================================================================

class _SidebarThemeTokens {
  const _SidebarThemeTokens({
    required this.background,
    required this.border,
    required this.avatarBackground,
    required this.brandIcon,
    required this.title,
    required this.subtitle,
    required this.unselectedForeground,
    required this.selectedForeground,
    required this.utilityDivider,
    required this.dangerForeground,
    required this.activeGradientStart,
    required this.activeGradientEnd,
  });

  factory _SidebarThemeTokens.fromColorScheme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;

    return _SidebarThemeTokens(
      background: isDark ? scheme.surfaceContainer : scheme.surface,
      border: scheme.outlineVariant.withValues(alpha: kBorderAlpha),
      avatarBackground: scheme.surfaceContainerHighest,
      brandIcon: scheme.primary,
      title: scheme.primary,
      subtitle: scheme.onSurface.withValues(alpha: kSubtitleAlpha),
      unselectedForeground: scheme.onSurface.withValues(
        alpha: kUnselectedForegroundAlpha,
      ),
      selectedForeground: scheme.onPrimary,
      utilityDivider: scheme.outlineVariant.withValues(
        alpha: kUtilityDividerAlpha,
      ),
      dangerForeground: scheme.error,
      activeGradientStart: scheme.primary,
      activeGradientEnd: Color.lerp(
        scheme.primary,
        scheme.primaryContainer,
        kGradientEndLerpFactor,
      )!,
    );
  }

  final Color background;
  final Color border;
  final Color avatarBackground;
  final Color brandIcon;
  final Color title;
  final Color subtitle;
  final Color unselectedForeground;
  final Color selectedForeground;
  final Color utilityDivider;
  final Color dangerForeground;
  final Color activeGradientStart;
  final Color activeGradientEnd;
}
