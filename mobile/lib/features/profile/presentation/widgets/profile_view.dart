import 'package:flutter/material.dart';
import 'package:music_room/core/config/app_config.dart';
import 'package:music_room/core/widgets/app_back_button.dart';
import 'package:music_room/features/playlist/domain/entities/playlist_entity.dart';
import 'package:music_room/features/profile/domain/entities/profile_entity.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({
    required this.data,
    required this.onRefresh,
    this.onEditProfile,
    this.onChangeAvatar,
    this.onOpenRoom,
    this.onOpenPlaylist,
    this.onLogout,
    this.isBusy = false,
    this.busyLabel,
    super.key,
  });

  final ProfilePageData data;
  final Future<void> Function() onRefresh;
  final VoidCallback? onEditProfile;
  final VoidCallback? onChangeAvatar;
  final void Function(ProfileRoomEntity room)? onOpenRoom;
  final void Function(PlaylistEntity playlist)? onOpenPlaylist;
  final VoidCallback? onLogout;
  final bool isBusy;
  final String? busyLabel;

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profile = widget.data.profile;
    final isOwnProfile = profile.isSelf;
    final hasShortBio =
        profile.shortBio != null && profile.shortBio!.trim().isNotEmpty;
    final roomTabLabel = isOwnProfile ? 'My Rooms' : 'Rooms';
    final playlistTabLabel = isOwnProfile ? 'My Playlists' : 'Playlists';
    final rooms = widget.data.hostedRooms;
    final playlists = widget.data.playlists;

    return Stack(
      children: [
        RefreshIndicator(
          color: colorScheme.primary,
          onRefresh: widget.onRefresh,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Row(
                    children: [
                      if (!isOwnProfile)
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
                      if (isOwnProfile && widget.onLogout != null)
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
                  ),
                  const SizedBox(height: 16),
                  _ProfileHeroCard(
                    profile: profile,
                    isOwnProfile: isOwnProfile,
                    onEditProfile: widget.onEditProfile,
                    onChangeAvatar: widget.onChangeAvatar,
                  ),
                  const SizedBox(height: 16),
                  _StatsRow(
                    roomsCount: widget.data.roomsCount,
                    followersCount: widget.data.followersCount,
                    followingCount: widget.data.followingCount,
                  ),
                  // Dedicated Bio card moved out of hero
                  if (hasShortBio) ...[
                    const SizedBox(height: 16),
                    _BioCard(
                      bio: profile.shortBio!.trim(),
                    ),
                  ],
                  if (isOwnProfile) ...[
                    const SizedBox(height: 16),
                    _PremiumCard(subscriptionTier: profile.subscriptionTier),
                  ] else ...[
                    const SizedBox(height: 12),
                    _RelationshipRow(profile: profile),
                  ],
                  const SizedBox(height: 16),
                  _SegmentedControl(
                    firstLabel: roomTabLabel,
                    secondLabel: playlistTabLabel,
                    selectedIndex: _selectedTabIndex,
                    onChanged: (index) {
                      setState(() {
                        _selectedTabIndex = index;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _selectedTabIndex == 0
                        ? _RoomsSection(
                            key: const ValueKey<String>('rooms'),
                            rooms: rooms,
                            isOwnProfile: isOwnProfile,
                            onOpenRoom: widget.onOpenRoom,
                          )
                        : _PlaylistsSection(
                            key: const ValueKey<String>('playlists'),
                            playlists: playlists,
                            isOwnProfile: isOwnProfile,
                            onOpenPlaylist: widget.onOpenPlaylist,
                          ),
                  ),
                  if (isOwnProfile) ...[
                    const SizedBox(height: 16),
                    _PrivateInfoCard(profile: profile),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (widget.isBusy)
          Positioned.fill(
            child: IgnorePointer(
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
    this.onEditProfile,
    this.onChangeAvatar,
  });

  final UserProfileEntity profile;
  final bool isOwnProfile;
  final VoidCallback? onEditProfile;
  final VoidCallback? onChangeAvatar;

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
                          child: isOwnProfile && onEditProfile != null
                              ? FilledButton.tonal(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: bannerTextColor.withValues(
                                      alpha: isLight ? 0.12 : 0.16,
                                    ),
                                    foregroundColor: bannerTextColor,
                                  ),
                                  onPressed: onEditProfile,
                                  child: const Text('Edit Profile'),
                                )
                              : const SizedBox.shrink(),
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
                                fontSize: 29,
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
                                  ),
                                if (!isOwnProfile && profile.isFollowing)
                                  const _BannerChip(
                                    icon: Icons.favorite_rounded,
                                    label: 'Following',
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
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.avatarUrl,
    required this.username,
    this.onTap,
  });

  final String? avatarUrl;
  final String username;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imageUrl = _resolveImageUrl(avatarUrl);

    final avatar = Container(
      width: 96,
      height: 96,
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

class _RelationshipRow extends StatelessWidget {
  const _RelationshipRow({required this.profile});

  final UserProfileEntity profile;

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[];
    if (profile.isFollowing) {
      badges.add(
        const _RelationshipChip(
          label: 'Following',
          icon: Icons.favorite_rounded,
        ),
      );
    }
    if (profile.isFollowedBy) {
      badges.add(
        const _RelationshipChip(
          label: 'Follows you',
          icon: Icons.person_rounded,
        ),
      );
    }
    if (profile.isFriend) {
      badges.add(
        const _RelationshipChip(label: 'Friend', icon: Icons.groups_rounded),
      );
    }

    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: badges,
    );
  }
}

class _RelationshipChip extends StatelessWidget {
  const _RelationshipChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({
    required this.firstLabel,
    required this.secondLabel,
    required this.selectedIndex,
    required this.onChanged,
  });

  final String firstLabel;
  final String secondLabel;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.secondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              label: firstLabel,
              selected: selectedIndex == 0,
              onTap: () => onChanged(0),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SegmentButton(
              label: secondLabel,
              selected: selectedIndex == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: selected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurface.withValues(alpha: 0.68),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomsSection extends StatelessWidget {
  const _RoomsSection({
    required this.rooms,
    required this.isOwnProfile,
    this.onOpenRoom,
    super.key,
  });

  final List<ProfileRoomEntity> rooms;
  final bool isOwnProfile;
  final void Function(ProfileRoomEntity room)? onOpenRoom;

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      return _EmptyStateCard(
        icon: Icons.queue_music_rounded,
        title: isOwnProfile ? 'No rooms yet' : 'No public rooms yet',
        message: isOwnProfile
            ? 'Your hosted rooms will appear here once you create an event.'
            : 'This user has not exposed any hosted rooms through the current '
                  'API.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rooms.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 2 : 1,
            mainAxisExtent: 140,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final room = rooms[index];
            return _RoomCard(
              room: room,
              onTap: onOpenRoom == null ? null : () => onOpenRoom!(room),
            );
          },
        );
      },
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room, this.onTap});

  final ProfileRoomEntity room;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final imageUrl = _resolveImageUrl(room.thumbnailUrl);

    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 72,
              height: 72,
              child: imageUrl == null
                  ? ColoredBox(
                      color: colorScheme.primaryContainer,
                      child: Icon(
                        Icons.music_note_rounded,
                        color: colorScheme.primary,
                        size: 30,
                      ),
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => ColoredBox(
                        color: colorScheme.primaryContainer,
                        child: Icon(
                          Icons.music_note_rounded,
                          color: colorScheme.primary,
                          size: 30,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        room.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _LiveBadge(isLive: room.isLive),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${room.status} · ${room.membersCount} listeners',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  room.hostName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.52),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: card,
      ),
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
            return _PlaylistCard(
              playlist: playlist,
              onTap: onOpenPlaylist == null
                  ? null
                  : () => onOpenPlaylist!(playlist),
            );
          },
        );
      },
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({required this.playlist, this.onTap});

  final PlaylistEntity playlist;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final thumbnail = _resolveImageUrl(playlist.thumbnailUrl);

    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 72,
              height: 72,
              child: thumbnail == null
                  ? ColoredBox(
                      color: colorScheme.primaryContainer,
                      child: Icon(
                        Icons.queue_music_rounded,
                        color: colorScheme.primary,
                        size: 30,
                      ),
                    )
                  : Image.network(
                      thumbnail,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => ColoredBox(
                        color: colorScheme.primaryContainer,
                        child: Icon(
                          Icons.queue_music_rounded,
                          color: colorScheme.primary,
                          size: 30,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${playlist.visibility} · ${playlist.trackCount} tracks',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
                if (playlist.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: playlist.tags
                        .take(2)
                        .map(
                          (tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              tag,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

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

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.isLive});

  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isLive
            ? colorScheme.error.withValues(alpha: 0.16)
            : colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isLive ? 'LIVE' : 'ROOM',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: isLive ? colorScheme.error : colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
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
        borderRadius: BorderRadius.circular(24),
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
    final genres = rawGenres
        .whereType<String>()
        .map((genre) => genre.trim())
        .where((genre) => genre.isNotEmpty)
        .take(3)
        .toList(growable: false);

    if (genres.isNotEmpty) {
      return genres.join(' · ');
    }
  }

  return null;
}

String? _resolveImageUrl(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }

  if (value.startsWith('http')) {
    return value;
  }

  final baseUrl = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
  final normalizedPath = value.replaceAll(RegExp('^/+'), '');
  return '$baseUrl/$normalizedPath';
}

String _formatCount(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return value.toString();
}
