import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:music_room/core/utils/image_url.dart';
import 'package:music_room/core/utils/tag_genre_normalizer.dart';
import 'package:music_room/core/widgets/app_back_button.dart';
import 'package:music_room/core/widgets/confirmation_dialog.dart';
import 'package:music_room/core/widgets/premium_segmented_tab_bar.dart';
import 'package:music_room/core/widgets/responsive_layout.dart';
import 'package:music_room/features/auth/presentation/state/auth_bloc.dart';
import 'package:music_room/features/auth/presentation/state/auth_event.dart';
import 'package:music_room/features/music_vote/data/models/my_event_item.dart';
import 'package:music_room/features/music_vote/presentation/widgets/my_event_list_tile.dart';
import 'package:music_room/features/playlist/domain/entities/playlist_entity.dart';
import 'package:music_room/features/profile/domain/entities/hosted_event_entity.dart';

import 'package:music_room/features/profile/domain/entities/profile_entity.dart';
import 'package:music_room/features/profile/presentation/state/profile_bloc.dart';
import 'package:music_room/features/profile/presentation/state/profile_event.dart';
import 'package:music_room/features/profile/presentation/widgets/media_card.dart';
import 'package:music_room/routes/route_names.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({
    required this.data,
    required this.onRefresh,
    this.showBackButton = false,
    this.onFollowProfile,
    this.onOpenRoom,
    this.onOpenPlaylist,
    this.isBusy = false,
    this.busyLabel,
    super.key,
  });

  final ProfilePageData data;
  final Future<void> Function() onRefresh;
  final bool showBackButton;
  final VoidCallback? onFollowProfile;
  final void Function(HostedEventEntity room)? onOpenRoom;
  final void Function(PlaylistEntity playlist)? onOpenPlaylist;
  final bool isBusy;
  final String? busyLabel;

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  int _selectedTabIndex = 0;

  // ── Shared data accessors ────────────────────────────────────────

  UserProfileEntity get _profile => widget.data.profile;
  bool get _isOwnProfile => _profile.isSelf;
  bool get _hasShortBio =>
      _profile.shortBio != null && _profile.shortBio!.trim().isNotEmpty;
  String get _roomTabLabel => _isOwnProfile ? 'My Rooms' : 'Rooms';
  String get _playlistTabLabel => _isOwnProfile ? 'My Playlists' : 'Playlists';

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      builder: (context, screenSize) {
        return switch (screenSize) {
          ScreenSize.compact => _buildCompact(context),
          ScreenSize.medium => _buildMedium(context),
          ScreenSize.expanded => _buildExpanded(context),
        };
      },
    );
  }

  // ── Compact (< 600px) — original mobile layout ──────────────────

  Widget _buildCompact(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _wrapWithBusyOverlay(
      context,
      child: RefreshIndicator(
        color: colorScheme.primary,
        onRefresh: widget.onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            _buildHeroCard(),
            const SizedBox(height: 16),
            _buildStatsRow(),
            if (_hasShortBio) ...[
              const SizedBox(height: 16),
              _BioCard(bio: _profile.shortBio!.trim()),
            ],
            const SizedBox(height: 16),
            _PremiumCard(subscriptionTier: _profile.subscriptionTier),
            const SizedBox(height: 16),
            _buildSegmentedControl(),
            const SizedBox(height: 16),
            _buildTabContent(),
          ],
        ),
      ),
    );
  }

  // ── Medium (600–1024px) — centered, tighter max-width ───────────

  Widget _buildMedium(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _wrapWithBusyOverlay(
      context,
      child: RefreshIndicator(
        color: colorScheme.primary,
        onRefresh: widget.onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 16),
                      _buildHeroCard(),
                      const SizedBox(height: 16),
                      _buildStatsRow(),
                      if (_hasShortBio) ...[
                        const SizedBox(height: 16),
                        _BioCard(bio: _profile.shortBio!.trim()),
                      ],
                      const SizedBox(height: 16),
                      _PremiumCard(subscriptionTier: _profile.subscriptionTier),
                      const SizedBox(height: 16),
                      _buildSegmentedControl(),
                      const SizedBox(height: 16),
                      _buildTabContent(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Expanded (≥ 1024px) — two-column desktop layout ─────────────

  Widget _buildExpanded(BuildContext context) {
    return _wrapWithBusyOverlay(
      context,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1060),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 20, 32, 48),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left — identity sidebar
                  SizedBox(
                    width: 340,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: 16),
                        _buildHeroCard(desktopScale: true),
                        const SizedBox(height: 16),
                        _buildStatsRow(),
                        if (_hasShortBio) ...[
                          const SizedBox(height: 16),
                          _BioCard(bio: _profile.shortBio!.trim()),
                        ],
                        const SizedBox(height: 16),
                        _PremiumCard(
                          subscriptionTier: _profile.subscriptionTier,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 28),

                  // Right — content area
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 38),
                        _buildSegmentedControl(),
                        const SizedBox(height: 16),
                        _buildTabContent(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Shared widget builders ──────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canGoBack = widget.showBackButton || !_isOwnProfile;

    return Row(
      children: [
        if (canGoBack)
          AppBackButton(
            color: colorScheme.onSurface,
            padding: EdgeInsets.zero,
          ),
        Expanded(
          child: Text(
            'Profile',
            style: theme.textTheme.displaySmall?.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard({bool desktopScale = false}) {
    return _ProfileHeroCard(
      profile: _profile,
      isOwnProfile: _isOwnProfile,
      onFollowProfile: widget.onFollowProfile,
      avatarRadius: desktopScale ? 56 : 48,
      usernameFontSize: desktopScale ? 32 : 29,
    );
  }

  Widget _buildStatsRow() {
    return _StatsRow(
      roomsCount: widget.data.roomsCount,
      followersCount: widget.data.followersCount,
      followingCount: widget.data.followingCount,
    );
  }

  Widget _buildSegmentedControl() {
    return DefaultTabController(
      length: 2,
      initialIndex: _selectedTabIndex,
      child: PremiumSegmentedTabBar(
        onTap: (index) {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        tabs: [
          Tab(text: _roomTabLabel),
          Tab(text: _playlistTabLabel),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _selectedTabIndex == 0
          ? _HostedEventsSection(
              key: const ValueKey<String>('rooms'),
              events: widget.data.hostedRooms,
              isOwnProfile: _isOwnProfile,
              onOpenEvent: widget.onOpenRoom,
            )
          : _PlaylistsSection(
              key: const ValueKey<String>('playlists'),
              playlists: widget.data.playlists,
              isOwnProfile: _isOwnProfile,
              onOpenPlaylist: widget.onOpenPlaylist,
            ),
    );
  }

  /// Busy overlay shown on top during mutations.
  Widget _wrapWithBusyOverlay(BuildContext context, {required Widget child}) {
    if (!widget.isBusy) return child;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: AbsorbPointer(
            child: ColoredBox(
              color: colorScheme.surface.withValues(alpha: 0.52),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Card(
                    elevation: 12,
                    color: colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 14),
                          Text(
                            widget.busyLabel ?? 'Updating profile...',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _ProfileHeaderAction {
  settings,
  logout,
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.profile,
    required this.isOwnProfile,
    this.onFollowProfile,
    this.avatarRadius = 48,
    this.usernameFontSize = 29,
  });

  final UserProfileEntity profile;
  final bool isOwnProfile;
  final VoidCallback? onFollowProfile;
  final double avatarRadius;
  final double usernameFontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final bannerGradient = LinearGradient(
      colors: isLight
          ? [
              colorScheme.primaryContainer,
              colorScheme.secondaryContainer,
              colorScheme.tertiaryContainer,
            ]
          : [
              colorScheme.primary.withValues(alpha: 0.94),
              colorScheme.primaryContainer.withValues(alpha: 0.78),
              colorScheme.secondary.withValues(alpha: 0.94),
            ],
    );
    final bannerTextColor = isLight
        ? colorScheme.onPrimaryContainer
        : Colors.white;

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Container(
        decoration: BoxDecoration(
          gradient: bannerGradient,
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -36,
              top: -20,
              child: _DecorBlob(
                color: Colors.white.withValues(alpha: 0.12),
                size: 130,
              ),
            ),
            Positioned(
              left: -20,
              bottom: -30,
              child: _DecorBlob(
                color: Colors.white.withValues(alpha: 0.08),
                size: 110,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _buildHeaderAction(
                            context: context,
                            bannerTextColor: bannerTextColor,
                            isLight: isLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 64),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _ProfileAvatar(
                        avatarUrl: profile.avatarUrl,
                        username: profile.username,
                        size: avatarRadius * 2,
                        onTap: isOwnProfile
                            ? () async {
                                try {
                                  final picker = ImagePicker();
                                  final picked = await picker.pickImage(
                                    source: ImageSource.gallery,
                                    imageQuality: 88,
                                    maxWidth: 1600,
                                  );

                                  if (picked == null) return;

                                  final bytes = await picked.readAsBytes();

                                  // Dispatch upload event to the ProfileBloc
                                  if (context.mounted) {
                                    context.read<ProfileBloc>().add(
                                      ProfileAvatarUploadRequested(
                                        bytes: bytes,
                                        fileName: picked.name,
                                      ),
                                    );
                                  }
                                } on Exception catch (error, stackTrace) {
                                  if (context.mounted) {
                                    context.read<ProfileBloc>().add(
                                      ProfileAvatarUploadFailed(
                                        exception: error,
                                        stackTrace: stackTrace,
                                      ),
                                    );
                                  }
                                }
                              }
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: bannerTextColor,
                                fontSize: usernameFontSize,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _profileSubtitle(profile),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: bannerTextColor.withValues(alpha: 0.86),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _BannerChip(
                                  icon: Icons.workspace_premium_rounded,
                                  label: profile.subscriptionTier,
                                  useLightStyle: isLight,
                                ),
                                if (!isOwnProfile && profile.isFriend)
                                  const _BannerChip(
                                    icon: Icons.people_alt_rounded,
                                    label: 'Friend',
                                    useLightStyle: true,
                                  ),
                                if (!isOwnProfile &&
                                    profile.isFollowing &&
                                    !profile.isFriend)
                                  const _BannerChip(
                                    icon: Icons.favorite_rounded,
                                    label: 'Following',
                                    useLightStyle: true,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderAction({
    required BuildContext context,
    required Color bannerTextColor,
    required bool isLight,
  }) {
    if (isOwnProfile) {
      return PopupMenuButton<_ProfileHeaderAction>(
        tooltip: 'Profile actions',
        icon: Icon(Icons.more_horiz_rounded, color: bannerTextColor),
        color: Theme.of(context).colorScheme.surface,
        elevation: 14,
        surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        offset: const Offset(0, 14),
        onSelected: (action) async {
          switch (action) {
            case _ProfileHeaderAction.settings:
              final saved = await Navigator.of(context).pushNamed(
                RouteNames.settings,
              );
              if (saved == true && context.mounted) {
                context.read<ProfileBloc>().add(
                  const ProfileRefreshRequested(),
                );
              }
              return;
            case _ProfileHeaderAction.logout:
              final confirmed = await showAppConfirmationDialog(
                context: context,
                title: 'Log out?',
                message:
                    'You will be signed out from this device. You can sign in'
                    ' again later.',
                confirmLabel: 'Log out',
                icon: Icons.logout_rounded,
                variant: ConfirmationDialogVariant.destructive,
              );

              if (confirmed == true && context.mounted) {
                context.read<AuthBloc>().add(const LogoutRequested());
              }
              return;
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<_ProfileHeaderAction>(
            value: _ProfileHeaderAction.settings,
            child: Row(
              children: [
                Icon(
                  Icons.settings_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                const Text('Settings'),
              ],
            ),
          ),
          PopupMenuItem<_ProfileHeaderAction>(
            value: _ProfileHeaderAction.logout,
            child: Row(
              children: [
                Icon(
                  Icons.logout_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 12),
                Text(
                  'Log out',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final label = _followButtonLabel(profile);
    if (label == null) {
      return const SizedBox.shrink();
    }

    final isActionable = onFollowProfile != null;
    final isDanger = label == 'Unfollow';

    return FilledButton.tonalIcon(
      style: FilledButton.styleFrom(
        backgroundColor: isDanger
            ? Theme.of(context).colorScheme.primary
            : bannerTextColor.withValues(alpha: isLight ? 0.12 : 0.16),
        foregroundColor: isDanger
            ? Theme.of(context).colorScheme.onErrorContainer
            : bannerTextColor,
      ),
      onPressed: isActionable ? onFollowProfile : null,
      icon: Icon(_followButtonIcon(profile)),
      label: Text(label),
    );
  }

  static String? _followButtonLabel(UserProfileEntity profile) {
    if (profile.isFriend || profile.isFollowing) {
      return 'Unfollow';
    }

    if (profile.isFollowedBy) {
      return 'Follow Back';
    }

    return 'Follow';
  }

  static IconData _followButtonIcon(UserProfileEntity profile) {
    if (profile.isFriend || profile.isFollowing) {
      return Icons.remove_circle_outline_rounded;
    }

    if (profile.isFollowedBy) {
      return Icons.person_add_alt_1_rounded;
    }

    return Icons.person_add_rounded;
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.avatarUrl,
    required this.username,
    this.size = 96,
    this.onTap,
  });

  final String? avatarUrl;
  final String username;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imageUrl = resolveImageUrl(avatarUrl);

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(
        child: imageUrl == null
            ? Container(
                color: colorScheme.primaryContainer,
                alignment: Alignment.center,
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: colorScheme.primaryContainer,
                    alignment: Alignment.center,
                    child: Text(
                      username.isNotEmpty ? username[0].toUpperCase() : '?',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  );
                },
              ),
      ),
    );

    final decoratedAvatar = Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        if (onTap != null)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.onSurface.withValues(alpha: 0.08),
                ),
              ),
              child: Icon(
                Icons.photo_camera_rounded,
                size: 16,
                color: colorScheme.primary,
              ),
            ),
          ),
      ],
    );

    if (onTap == null) {
      return decoratedAvatar;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: decoratedAvatar,
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.roomsCount,
    required this.followersCount,
    required this.followingCount,
  });

  final int roomsCount;
  final int followersCount;
  final int followingCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(label: 'Rooms', value: roomsCount),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(label: 'Followers', value: followersCount),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(label: 'Following', value: followingCount),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Text(
            _formatCount(value),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.subscriptionTier});

  final String subscriptionTier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isPremium = subscriptionTier.toUpperCase() != 'BASIC';

    final isLight = theme.brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLight
              ? [
                  colorScheme.surface,
                  colorScheme.primaryContainer.withValues(alpha: 0.72),
                  colorScheme.secondaryContainer.withValues(alpha: 0.82),
                ]
              : [
                  colorScheme.primaryContainer,
                  colorScheme.primary.withValues(alpha: 0.42),
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.workspace_premium_rounded,
              color: isPremium ? colorScheme.primary : colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPremium ? 'Premium Active' : 'Free Plan',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPremium
                      ? 'Unlimited rooms · HD audio · No ads'
                      : 'Upgrade for premium room controls and HD audio.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPremium
                    ? [colorScheme.primary, colorScheme.secondary]
                    : [colorScheme.surface, colorScheme.surface],
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              isPremium ? 'Premium' : 'Free',
              style: theme.textTheme.labelLarge?.copyWith(
                color: isPremium
                    ? Colors.white
                    : colorScheme.onSurface.withValues(alpha: 0.8),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HostedEventsSection extends StatelessWidget {
  const _HostedEventsSection({
    required this.events,
    required this.isOwnProfile,
    this.onOpenEvent,
    super.key,
  });

  final List<HostedEventEntity> events;
  final bool isOwnProfile;
  final void Function(HostedEventEntity)? onOpenEvent;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return _EmptyStateCard(
        icon: Icons.queue_music_rounded,
        title: isOwnProfile ? 'No rooms yet' : 'No public rooms yet',
        message: isOwnProfile
            ? 'Your hosted rooms will appear here once you create an event.'
            : 'This user has not exposed any hosted rooms '
                  'through the current API.',
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: events.length,
      itemBuilder: (_, index) {
        final event = events[index];
        return MyEventListTile(
          event: _toMyEventItem(event),
          onTap: onOpenEvent == null ? null : () => onOpenEvent!(event),
        );
      },
    );
  }

  MyEventItem _toMyEventItem(HostedEventEntity event) {
    return MyEventItem(
      id: event.id,
      name: event.name,
      hostName: event.hostName,
      hostId: event.hostId,
      dateTime: event.dateTime,
      status: event.status,
      coverImageAsset: event.coverImageAsset,
      coverColorHex: event.coverColorHex,
      listenerCount: event.listenerCount,
      genre: event.genre,
    );
  }
}

class _PlaylistsSection extends StatelessWidget {
  const _PlaylistsSection({
    required this.playlists,
    required this.isOwnProfile,
    this.onOpenPlaylist,
    super.key,
  });

  final List<PlaylistEntity> playlists;
  final bool isOwnProfile;
  final void Function(PlaylistEntity playlist)? onOpenPlaylist;

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) {
      return _EmptyStateCard(
        icon: Icons.library_music_rounded,
        title: isOwnProfile ? 'No playlists yet' : 'No playlists exposed',
        message: isOwnProfile
            ? 'Your playlists will show here once you create one.'
            : "The current backend only exposes the authenticated user's "
                  'playlists.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: playlists.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 2 : 1,
            mainAxisExtent: 140,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            final data = PlaylistCardData(
              id: playlist.id,
              name: playlist.name,
              thumbnailUrl: playlist.thumbnailUrl,
              visibility: playlist.visibility,
              trackCount: playlist.trackCount,
              tags: playlist.tags,
              collageImageUrls: playlist.collageImageUrls,
            );

            return SizedBox(
              height: 140,
              child: MediaCard(
                data: data,
                onTap: onOpenPlaylist == null
                    ? null
                    : () => onOpenPlaylist!(playlist),
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: colorScheme.primary),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.68),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerChip extends StatelessWidget {
  const _BannerChip({
    required this.icon,
    required this.label,
    this.useLightStyle = false,
  });

  final IconData icon;
  final String label;
  final bool useLightStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: useLightStyle
            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: useLightStyle
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: useLightStyle
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DecorBlob extends StatelessWidget {
  const _DecorBlob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

String _profileSubtitle(UserProfileEntity profile) {
  // Show genres, email (for self) or subscription tier in hero subtitle.
  final genreText = _profileGenres(profile);
  if (genreText != null) {
    return genreText;
  }

  if (profile.isSelf && profile.email != null) {
    return profile.email!;
  }

  return profile.subscriptionTier;
}

class _BioCard extends StatelessWidget {
  const _BioCard({required this.bio});

  final String bio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Text(
        bio,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.88),
        ),
      ),
    );
  }
}

String? _profileGenres(UserProfileEntity profile) {
  final preferences = profile.preferences;
  if (preferences is! Map<String, dynamic>) {
    return null;
  }

  final rawGenres =
      preferences['genres'] ??
      preferences['favoriteGenres'] ??
      preferences['tags'];

  if (rawGenres is List<dynamic>) {
    final genres = TagGenreNormalizer.toDisplayLabels(rawGenres, limit: 3);

    if (genres.isNotEmpty) {
      return genres.join(' · ');
    }
  }

  return null;
}

// Image URL resolution handled by `core/utils/image_url.dart`.

String _formatCount(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return value.toString();
}
