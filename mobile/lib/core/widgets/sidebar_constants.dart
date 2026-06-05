// =============================================================================
// LAYOUT — Sidebar dimensions & padding
// =============================================================================

/// Width of the sidebar when labels are visible alongside icons (desktop).
const double kSidebarExtendedWidth = 260;

/// Width of the sidebar when only icons are shown (tablet).
const double kSidebarCollapsedWidth = 80;

/// Horizontal padding inside the sidebar when it is in extended (label) mode.
const double kSidebarExtendedPadding = 22;

/// Horizontal padding inside the sidebar when it is in collapsed (icon) mode.
const double kSidebarCollapsedPadding = 14;

/// Top padding at the start of the sidebar content area.
const double kSidebarTopPadding = 20;

/// Bottom padding at the end of the sidebar content area.
const double kSidebarBottomPadding = 18;

/// Vertical gap between the header and the first nav item (extended mode).
const double kSidebarHeaderGapExtended = 30;

/// Vertical gap between the header and the first nav item (collapsed mode).
const double kSidebarHeaderGapCollapsed = 20;

/// Vertical gap between consecutive nav items.
const double kSidebarNavItemGap = 10;

/// Vertical gap between the divider and the first utility button (extended).
const double kSidebarUtilityGapExtended = 14;

/// Vertical gap between the divider and the first utility button (collapsed).
const double kSidebarUtilityGapCollapsed = 10;

/// Vertical gap between consecutive utility buttons.
const double kSidebarUtilityButtonGap = 6;

// =============================================================================
// LAYOUT — Nav item dimensions
// =============================================================================

/// Height of each navigation item row in the sidebar.
const double kNavItemHeight = 48;

/// Horizontal padding inside a nav item when labels are visible.
const double kNavItemHorizontalPaddingExtended = 14;

/// Gap between the nav item icon and its label.
const double kNavItemIconLabelGap = 14;

/// Border radius applied to nav item ink-well and gradient background.
const double kNavItemBorderRadius = 10;

/// Size of the icon inside a nav item.
const double kNavItemIconSize = 22;

// =============================================================================
// LAYOUT — Utility button dimensions
// =============================================================================

/// Height of each utility button row (theme toggle, settings, logout).
const double kUtilityButtonHeight = 44;

/// Horizontal padding inside a utility button when labels are visible.
const double kUtilityButtonHorizontalPaddingExtended = 14;

/// Gap between the utility button icon and its label.
const double kUtilityButtonIconLabelGap = 14;

/// Border radius applied to utility button ink-wells.
const double kUtilityButtonBorderRadius = 10;

/// Size of the icon inside a utility button.
const double kUtilityButtonIconSize = 20;

// =============================================================================
// LAYOUT — Sidebar header dimensions
// =============================================================================

/// Avatar container size when the sidebar is in extended mode.
const double kAvatarSizeExtended = 54;

/// Avatar container size when the sidebar is in collapsed mode.
const double kAvatarSizeCollapsed = 42;

/// Brand icon size when the sidebar is in extended mode.
const double kBrandIconSizeExtended = 30;

/// Brand icon size when the sidebar is in collapsed mode.
const double kBrandIconSizeCollapsed = 24;

/// Gap between the avatar and the text block in extended mode.
const double kHeaderAvatarTextGap = 12;

/// Gap between the display name and the subtitle.
const double kHeaderTitleSubtitleGap = 5;

// =============================================================================
// LAYOUT — Bottom navigation bar
// =============================================================================

/// Size of icons in the bottom navigation bar.
const double kBottomNavIconSize = 28;

// =============================================================================
// LAYOUT — Notification badge
// =============================================================================

/// Padding inside the circular notification badge.
const double kBadgePadding = 4;

/// Minimum tap target for the notification badge.
const double kBadgeMinSize = 20;

/// Horizontal offset of the badge relative to the icon's top-right corner.
const double kBadgeRightOffset = -6;

/// Vertical offset of the badge relative to the icon's top-right corner.
const double kBadgeTopOffset = -6;

/// Font size of the count label inside the badge.
const double kBadgeFontSize = 11;

/// Maximum count rendered as a number; above this "99+" is shown instead.
const int kMaxBadgeCount = 99;

// =============================================================================
// TYPOGRAPHY — Sidebar header
// =============================================================================

const double kHeaderTitleFontSize = 16;
const double kHeaderTitleLetterSpacing = -0.4;
const double kHeaderTitleLineHeight = 1.05;
const double kHeaderSubtitleFontSize = 15;
const double kHeaderSubtitleLetterSpacing = 0.1;

// =============================================================================
// TYPOGRAPHY — Nav items
// =============================================================================

const double kNavItemFontSize = 15;
const double kNavItemLetterSpacing = 0.1;

// =============================================================================
// TYPOGRAPHY — Utility buttons
// =============================================================================

const double kUtilityButtonFontSize = 14;
const double kUtilityButtonLetterSpacing = 0.1;

// =============================================================================
// ALPHA / OPACITY tokens — sidebar color derivation
// =============================================================================

/// Border alpha.
const double kBorderAlpha = 0.1;

/// Opacity of the subtitle text relative to onSurface.
const double kSubtitleAlpha = 0.72;

/// Opacity of unselected nav / utility foreground text relative to onSurface.
const double kUnselectedForegroundAlpha = 0.78;

/// Opacity of the utility-section divider.
const double kUtilityDividerAlpha = 0.5;

/// Opacity of the bottom-nav border line.
const double kBottomNavBorderAlpha = 0.1;

/// Opacity of unselected bottom-nav icons.
const double kBottomNavUnselectedAlpha = 0.4;

/// Lerp factor between primary and primaryContainer for the gradient end stop.
const double kGradientEndLerpFactor = 0.45;

// =============================================================================
// STRINGS — User profile header
// =============================================================================

const String kProfileDisplayName = 'Music Room';
const String kProfileSubtitle = 'Welcome event lover!';

// =============================================================================
// STRINGS — Theme preference keys
// =============================================================================

const String kThemePreferenceLight = 'LIGHT';
const String kThemePreferenceDark = 'DARK';

// =============================================================================
// STRINGS — Logout dialog
// =============================================================================

const String kLogoutDialogTitle = 'Log Out?';
const String kLogoutDialogMessage =
    'Are you sure you want to log out of your account?';
const String kLogoutDialogConfirmLabel = 'Log Out';
