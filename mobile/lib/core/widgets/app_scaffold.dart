import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:music_room/core/services/notifications_service.dart';
import 'package:music_room/core/widgets/app_brand_icon.dart';
import 'package:music_room/core/widgets/confirmation_dialog.dart';
import 'package:music_room/core/widgets/responsive_layout.dart';
import 'package:music_room/core/widgets/sidebar_constants.dart';
import 'package:music_room/core/widgets/upgrade_reminder_snackbar.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/auth/presentation/state/auth_event.dart';
import 'package:music_room/features/auth/presentation/state/auth_state.dart';
import 'package:music_room/features/home/presentation/pages/home_page.dart';
import 'package:music_room/features/music_vote/presentation/pages/my_events_page.dart';
import 'package:music_room/features/playlist/presentation/pages/playlist_page.dart';
import 'package:music_room/features/profile/presentation/pages/profile_page.dart';
import 'package:music_room/features/settings/presentation/pages/settings_page.dart';
import 'package:music_room/features/subscription/presentation/state/subscription_cubit.dart';
import 'package:music_room/routes/route_names.dart';

// =============================================================================
// NAVIGATION ITEM METADATA
// =============================================================================

class _NavItemData {
  const _NavItemData({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
}

const List<_NavItemData> _navItems = [
  _NavItemData(
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    route: RouteNames.home,
  ),
  _NavItemData(
    label: 'Events',
    icon: Icons.sensors,
    selectedIcon: Icons.sensors,
    route: RouteNames.events,
  ),
  _NavItemData(
    label: 'Playlists',
    icon: Icons.queue_music_outlined,
    selectedIcon: Icons.queue_music_rounded,
    route: RouteNames.playlists,
  ),
  _NavItemData(
    label: 'Profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    route: RouteNames.profile,
  ),
  _NavItemData(
    label: 'Settings',
    icon: Icons.settings_suggest_outlined,
    selectedIcon: Icons.settings_suggest_outlined,
    route: RouteNames.settings,
  ),
];

// =============================================================================
// APP SCAFFOLD - Shell Route Layout
// =============================================================================

class AppScaffold extends StatefulWidget {
  const AppScaffold({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<AppScaffold> createState() => AppScaffoldState();
}

class AppScaffoldState extends State<AppScaffold> {
  late final GlobalKey<ProfilePageState> _profilePageKey;
  late final List<Widget> _tabPages;
  String _currentLocation = '';
  GoRouterDelegate? _routerDelegate;

  @override
  void initState() {
    super.initState();
    _profilePageKey = GlobalKey<ProfilePageState>();
    _tabPages = [
      const HomePage(),
      const MyEventsPage(),
      const PlaylistPage(),
      ProfilePage(key: _profilePageKey),
      const SettingsPage(),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // One-time initialisation that needs InheritedWidget access.
    if (_routerDelegate == null) {
      _routerDelegate = GoRouter.of(context).routerDelegate;
      _updateCurrentLocation();
      _routerDelegate!.addListener(_onRouteChanged);
    }
  }

  @override
  void dispose() {
    _routerDelegate?.removeListener(_onRouteChanged);
    super.dispose();
  }

  void _onRouteChanged() {
    _updateCurrentLocation();
  }

  /// Walk the delegate's match tree to find the effective matched location.
  ///
  /// After a `context.push()` inside a ShellRoute,
  /// `GoRouterState.matchedLocation` is stale (it preserves the original shell
  /// match). The delegate's `currentConfiguration` contains the updated tree
  /// with the correct leaf `matchedLocation`, so we derive it from there.
  void _updateCurrentLocation() {
    final config = GoRouter.of(context).routerDelegate.currentConfiguration;
    if (config.matches.isEmpty) return;

    var current = config.matches.last;
    while (current is ShellRouteMatch) {
      current = current.matches.last;
    }
    final newLocation = current.matchedLocation;
    if (newLocation != _currentLocation) {
      setState(() {
        _currentLocation = newLocation;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Tab / route helpers
  // ---------------------------------------------------------------------------

  /// Returns the sidebar nav-item index (0-4) for [location], or -1 if none.
  int _sidebarIndexForRoute(String location) {
    if (location == RouteNames.home ||
        location.startsWith('${RouteNames.home}?')) {
      return 0;
    }
    if (location == RouteNames.events ||
        location.startsWith('${RouteNames.events}?') ||
        location.startsWith('${RouteNames.events}/')) {
      return 1;
    }
    if (location == RouteNames.playlists ||
        location.startsWith('${RouteNames.playlists}?') ||
        location.startsWith('${RouteNames.playlists}/')) {
      return 2;
    }
    if (location == RouteNames.profile ||
        location.startsWith('${RouteNames.profile}/') ||
        location.startsWith('${RouteNames.profile}?')) {
      return 3;
    }
    if (location == RouteNames.settings ||
        location.startsWith('${RouteNames.settings}?')) {
      return 4;
    }
    return -1;
  }

  /// True only for exact tab-route matches (no sub-routes).
  bool get _isExactTabPage =>
      _currentLocation == RouteNames.home ||
      _currentLocation == RouteNames.events ||
      _currentLocation == RouteNames.playlists ||
      _currentLocation == RouteNames.profile ||
      _currentLocation == RouteNames.settings;

  int get _currentSidebarIndex {
    final idx = _sidebarIndexForRoute(_currentLocation);
    return idx >= 0 ? idx : 0;
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _onNavItemTapped(int index) {
    if (index >= 0 && index < _navItems.length) {
      context.go(_navItems[index].route);
    }
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

  Widget _buildBodyContent() {
    if (_isExactTabPage) {
      return IndexedStack(
        index: _currentSidebarIndex,
        children: _tabPages,
      );
    }
    return widget.child;
  }

  // ---------------------------------------------------------------------------
  // Phone layout – BottomNavigationBar
  // ---------------------------------------------------------------------------

  Widget _buildWithBottomBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final notificationsService = InjectionContainer().notificationsService;

    return BlocBuilder<SubscriptionCubit, SubscriptionState>(
      builder: (context, subState) {
        final isBasic = subState is SubscriptionLoaded && subState.isBasic;

        return Scaffold(
          body: Stack(
            children: [
              _buildBodyContent(),
              UpgradeReminderSnackbar(
                visible: isBasic,
                onUpgrade: () => context.go(RouteNames.profile),
              ),
            ],
          ),
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
              currentIndex: _currentSidebarIndex,
              onTap: _onNavItemTapped,
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
                BottomNavigationBarItem(
                  icon: _HomeTabIcon(
                    notificationsService: notificationsService,
                    badgeColor: colorScheme.error,
                  ),
                  label: _navItems[0].label,
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
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Tablet / Desktop layout – custom sidebar rail
  // ---------------------------------------------------------------------------

  Widget _buildWithRail(BuildContext context, {required bool extended}) {
    final colorScheme = Theme.of(context).colorScheme;
    final sidebarColors = _SidebarThemeTokens.fromColorScheme(colorScheme);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<SubscriptionCubit, SubscriptionState>(
      builder: (context, subState) {
        final isBasic = subState is SubscriptionLoaded && subState.isBasic;

        return Scaffold(
          body: Row(
            children: [
              _Sidebar(
                extended: extended,
                colors: sidebarColors,
                isDarkMode: isDarkMode,
                currentIndex: _currentSidebarIndex,
                navItems: _navItems,
                onNavItemTap: _onNavItemTapped,
                onThemeToggle: () => _handleThemeToggle(isDarkMode),
                onLogoutTap: () => _handleLogout(context),
              ),
              Expanded(
                child: Stack(
                  children: [
                    _buildBodyContent(),
                    UpgradeReminderSnackbar(
                      visible: isBasic,
                      onUpgrade: () => context.go(RouteNames.profile),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
    required this.onLogoutTap,
  });

  final bool extended;
  final _SidebarThemeTokens colors;
  final bool isDarkMode;
  final int currentIndex;
  final List<_NavItemData> navItems;
  final ValueChanged<int> onNavItemTap;
  final VoidCallback onThemeToggle;
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
          icon: currentIndex == _navItems.indexOf(item)
              ? item.selectedIcon
              : item.icon,
          isSelected: currentIndex == _navItems.indexOf(item),
          onTap: () => onNavItemTap(_navItems.indexOf(item)),
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

  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final effectiveForeground = foregroundColor ?? colors.unselectedForeground;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kUtilityButtonBorderRadius),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kUtilityButtonBorderRadius),
          ),
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
