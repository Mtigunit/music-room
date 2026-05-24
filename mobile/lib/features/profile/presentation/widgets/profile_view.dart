import 'package:flutter/material.dart';
import 'package:music_room/core/utils/image_url.dart';
import 'package:music_room/core/utils/tag_genre_normalizer.dart';
import 'package:music_room/core/widgets/app_back_button.dart';
import 'package:music_room/core/widgets/app_button.dart';
import 'package:music_room/core/widgets/premium_segmented_tab_bar.dart';
import 'package:music_room/core/widgets/responsive_layout.dart';
import 'package:music_room/features/music_vote/data/models/my_event_item.dart';
import 'package:music_room/features/music_vote/presentation/widgets/my_event_list_tile.dart';
import 'package:music_room/features/playlist/domain/entities/playlist_entity.dart';
import 'package:music_room/features/profile/domain/entities/profile_entity.dart';
import 'package:music_room/features/profile/presentation/widgets/media_card.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({
    required this.data,
    required this.onRefresh,
    this.onFollowProfile,
    this.onEditProfile,
    this.onChangeAvatar,
    this.onOpenRoom,
    this.onOpenPlaylist,
    this.onLogout,
    this.onGoogleAccountAction,
    this.googleAccountMessage,
    this.isBusy = false,
    this.busyLabel,
    super.key,
  });

  final ProfilePageData data;
  final Future<void> Function() onRefresh;
  final VoidCallback? onFollowProfile;
  final VoidCallback? onEditProfile;
  final VoidCallback? onChangeAvatar;
  final void Function(MyEventItem room)? onOpenRoom;
  final void Function(PlaylistEntity playlist)? onOpenPlaylist;
  final VoidCallback? onLogout;
  final VoidCallback? onGoogleAccountAction;
  final String? googleAccountMessage;
  final bool isBusy;
  final String? busyLabel;

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  int _selectedTabIndex = 0;

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

  // ── Shared data accessors ────────────────────────────────────────

  UserProfileEntity get _profile => widget.data.profile;
  bool get _isOwnProfile => _profile.isSelf;
  bool get _hasShortBio =>
      _profile.shortBio != null && _profile.shortBio!.trim().isNotEmpty;
  String get _roomTabLabel => _isOwnProfile ? 'My Rooms' : 'Rooms';
  String get _playlistTabLabel => _isOwnProfile ? 'My Playlists' : 'Playlists';

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
            _buildHeader(context, showLogout: true),
            const SizedBox(height: 16),
            _buildHeroCard(),
            const SizedBox(height: 16),
            _buildStatsRow(),
            if (_hasShortBio) ...[
              const SizedBox(height: 16),
              _BioCard(bio: _profile.shortBio!.trim()),
            ],
            if (_isOwnProfile) ...[
              const SizedBox(height: 16),
              _PremiumCard(subscriptionTier: _profile.subscriptionTier),
            ] else ...[
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 16),
            _buildSegmentedControl(),
            const SizedBox(height: 16),
            _buildTabContent(),
            if (_isOwnProfile) ...[
              const SizedBox(height: 16),
              _PrivateInfoCard(profile: _profile),
              const SizedBox(height: 16),
              _GoogleAccountCard(
                profile: _profile,
                onAction: widget.onGoogleAccountAction,
                message: widget.googleAccountMessage,
              ),
            ],
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
                      _buildHeader(context, showLogout: true),
                      const SizedBox(height: 16),
                      _buildHeroCard(),
                      const SizedBox(height: 16),
                      _buildStatsRow(),
                      if (_hasShortBio) ...[
                        const SizedBox(height: 16),
                        _BioCard(bio: _profile.shortBio!.trim()),
                      ],
                      if (_isOwnProfile) ...[
                        const SizedBox(height: 16),
                        _PremiumCard(
                          subscriptionTier: _profile.subscriptionTier,
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 16),
                      _buildSegmentedControl(),
                      const SizedBox(height: 16),
                      _buildTabContent(),
                      if (_isOwnProfile) ...[
                        const SizedBox(height: 16),
                        _PrivateInfoCard(profile: _profile),
                        const SizedBox(height: 16),
                        _GoogleAccountCard(
                          profile: _profile,
                          onAction: widget.onGoogleAccountAction,
                          message: widget.googleAccountMessage,
                        ),
                      ],
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
                        _buildHeader(
                          context,
                          // Nav rail already has logout on desktop.
                          showLogout: false,
                        ),
                        const SizedBox(height: 16),
                        _buildHeroCard(desktopScale: true),
                        const SizedBox(height: 16),
                        _buildStatsRow(),
                        if (_hasShortBio) ...[
                          const SizedBox(height: 16),
                          _BioCard(bio: _profile.shortBio!.trim()),
                        ],
                        if (_isOwnProfile) ...[
                          const SizedBox(height: 16),
                          _PremiumCard(
                            subscriptionTier: _profile.subscriptionTier,
                          ),
                        ],
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
                        if (_isOwnProfile) ...[
                          const SizedBox(height: 16),
                          _PrivateInfoCard(profile: _profile),
                          const SizedBox(height: 16),
                          _GoogleAccountCard(
                            profile: _profile,
                            onAction: widget.onGoogleAccountAction,
                            message: widget.googleAccountMessage,
                          ),
                        ],
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

  Widget _buildHeader(
    BuildContext context, {
    required bool showLogout,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        if (!_isOwnProfile)
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
        if (showLogout && _isOwnProfile && widget.onLogout != null)
          IconButton(
            tooltip: 'Log out',
            onPressed: widget.onLogout,
            icon: Icon(
              Icons.logout_rounded,
              color: colorScheme.onSurface,
            ),
            splashRadius: 20,
          ),
      ],
    );
  }

  Widget _buildHeroCard({bool desktopScale = false}) {
    return _ProfileHeroCard(
      profile: _profile,
      isOwnProfile: _isOwnProfile,
      onFollowProfile: widget.onFollowProfile,
      onEditProfile: widget.onEditProfile,
      onChangeAvatar: widget.onChangeAvatar,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
  Widget _wrapWithBusyOverlay(
    BuildContext context, {
    required Widget child,
  }) {
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

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.profile,
    required this.isOwnProfile,
    this.onFollowProfile,
    this.onEditProfile,
    this.onChangeAvatar,
    this.avatarRadius = 48,
    this.usernameFontSize = 29,
  });

  final UserProfileEntity profile;
  final bool isOwnProfile;
  final VoidCallback? onFollowProfile;
  final VoidCallback? onEditProfile;
  final VoidCallback? onChangeAvatar;
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
                        onTap: isOwnProfile ? onChangeAvatar : null,
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
    if (isOwnProfile && onEditProfile != null) {
      return FilledButton.tonal(
        style: FilledButton.styleFrom(
          backgroundColor: bannerTextColor.withValues(
            alpha: isLight ? 0.12 : 0.16,
          ),
          foregroundColor: bannerTextColor,
        ),
        onPressed: onEditProfile,
        child: const Text('Edit Profile'),
      );
    }

    if (isOwnProfile) {
      return const SizedBox.shrink();
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
                    ? [
                        colorScheme.primary,
                        colorScheme.secondary,
                      ]
                    : [
                        colorScheme.surface,
                        colorScheme.surface,
                      ],
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

// Replaced by PremiumSegmentedTabBar for consistent styling across app.

class _HostedEventsSection extends StatelessWidget {
  const _HostedEventsSection({
    required this.events,
    required this.isOwnProfile,
    this.onOpenEvent,
    super.key,
  });

  final List<MyEventItem> events;
  final bool isOwnProfile;
  final void Function(MyEventItem)? onOpenEvent;

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
          event: event,
          onTap: onOpenEvent == null ? null : () => onOpenEvent!(event),
        );
      },
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

// Playlists now render with `MediaCard` (see MediaCard/PlaylistCardData).

class _PrivateInfoCard extends StatelessWidget {
  const _PrivateInfoCard({required this.profile});

  final UserProfileEntity profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Private details',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _InfoLine(label: 'Email', value: profile.email ?? 'Not set'),
          const SizedBox(height: 10),
          _InfoLine(
            label: 'Google account',
            value: switch (profile.googleLinkStatus) {
              GoogleLinkStatus.linked => 'Linked',
              GoogleLinkStatus.unlinked => 'Not linked',
              GoogleLinkStatus.unknown => 'Status unavailable',
            },
          ),
          const SizedBox(height: 10),
          _InfoLine(
            label: 'Preferences',
            value: profile.preferences == null || profile.preferences!.isEmpty
                ? 'Not set'
                : 'Stored in account settings',
          ),
        ],
      ),
    );
  }
}

class _GoogleAccountCard extends StatelessWidget {
  const _GoogleAccountCard({
    required this.profile,
    this.onAction,
    this.message,
  });

  final UserProfileEntity profile;
  final VoidCallback? onAction;
  final String? message;

  bool get _isLinked => profile.googleLinkStatus == GoogleLinkStatus.linked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _isLinked
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.g_mobiledata_rounded,
                  color: _isLinked ? colorScheme.primary : colorScheme.outline,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Google account',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isLinked
                          ? 'Linked to this account'
                          : 'No Google account linked',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.66),
                      ),
                    ),
                  ],
                ),
              ),
              _GoogleStatusChip(isLinked: _isLinked),
            ],
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            _InlineNotice(message: message!),
          ],
          if (_isLinked) ...[
            const SizedBox(height: 16),
            _GoogleLinkedDetails(profile: profile),
          ] else ...[
            const SizedBox(height: 16),
            Text(
              'Link Google to keep your account connection in sync across '
              'supported sign-in flows.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              onPressed: onAction,
              backgroundColor: _isLinked
                  ? colorScheme.errorContainer
                  : colorScheme.primaryContainer,
              foregroundColor: _isLinked
                  ? colorScheme.onErrorContainer
                  : colorScheme.onPrimaryContainer,
              disabledBackgroundColor: colorScheme.surfaceContainerHighest,
              disabledForegroundColor: colorScheme.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isLinked ? Icons.link_off_rounded : Icons.link_rounded,
                    size: 18,
                    color: _isLinked
                        ? colorScheme.onErrorContainer
                        : colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isLinked ? 'Remove Google Link' : 'Link Google Account',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: _isLinked
                          ? colorScheme.onErrorContainer
                          : colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleStatusChip extends StatelessWidget {
  const _GoogleStatusChip({required this.isLinked});

  final bool isLinked;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isLinked
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isLinked ? 'Linked' : 'Not linked',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: isLinked ? colorScheme.primary : colorScheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _GoogleLinkedDetails extends StatelessWidget {
  const _GoogleLinkedDetails({required this.profile});

  final UserProfileEntity profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final imageUrl = resolveImageUrl(profile.avatarUrl);

    return Column(
      children: [
        Row(
          children: [
            ClipOval(
              child: Container(
                width: 52,
                height: 52,
                color: colorScheme.primaryContainer,
                child: imageUrl == null
                    ? Icon(
                        Icons.person_rounded,
                        color: colorScheme.primary,
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.person_rounded,
                            color: colorScheme.primary,
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.email ?? 'Email not available',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.68),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const _InfoLine(label: 'Provider', value: 'Google'),
        const SizedBox(height: 10),
        const _InfoLine(
          label: 'Status',
          value: 'Linked and ready to remove at any time',
        ),
      ],
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.error.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onErrorContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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

    return Container(
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
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
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
