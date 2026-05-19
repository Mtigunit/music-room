import 'dart:async';

import 'package:flutter/material.dart';
import 'package:music_room/core/config/app_config.dart';
import 'package:music_room/core/widgets/app_scaffold.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/home/presentation/widgets/show_notification_panel.dart';
import 'package:music_room/routes/route_names.dart';

class HomeHeader extends StatefulWidget {
  const HomeHeader({
    super.key,
    this.greeting = 'Good evening',
  });

  final String greeting;

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> {
  String _username = 'djnova';
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    unawaited(_loadProfile());
  }

  @override
  void didUpdateWidget(covariant HomeHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  Future<void> _loadProfile() async {
    try {
      // Load cached username instantly
      final authRepo = InjectionContainer().authRepository;
      final storedUser = await authRepo.getStoredUserProfile();
      if (storedUser != null && storedUser.username != null) {
        if (mounted) {
          setState(() {
            _username = storedUser.username!;
          });
        }
      }

      // Load user profile (which contains avatarUrl)
      final profileDS = InjectionContainer().profileRemoteDataSource;
      final userProfile = await profileDS.getMyProfile();
      debugPrint('HomeHeader loaded user profile successfully.');
      if (mounted) {
        setState(() {
          _username = userProfile.username;
          _avatarUrl = userProfile.avatarUrl;
        });
      }
    } on Object catch (e) {
      debugPrint('Error loading profile in HomeHeader: $e');
    }
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.greeting,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _username,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Stack(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    tooltip: 'Notifications',
                    onPressed: () {
                      unawaited(
                        showNotificationPanel(context: context),
                      );
                    },
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: const CircleBorder(),
                      side: BorderSide(
                        color: colorScheme.onSurface.withValues(alpha: 0.1),
                      ),
                    ),
                    icon: Icon(
                      Icons.notifications_none,
                      size: 24,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 10,
                  child: StreamBuilder<int>(
                    stream: InjectionContainer()
                        .notificationsService
                        .unreadCountStream,
                    initialData:
                        InjectionContainer().notificationsService.unreadCount,
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      if (count == 0) return const SizedBox.shrink();
                      return Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Semantics(
              button: true,
              label: 'Open profile',
              child: Tooltip(
                message: 'Profile',
                child: Material(
                  type: MaterialType.transparency,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      final scaffoldState = context
                          .findAncestorStateOfType<AppScaffoldState>();
                      if (scaffoldState != null) {
                        scaffoldState.switchTab(AppTabs.profile);
                      } else {
                        unawaited(
                          Navigator.of(context).pushNamed(RouteNames.profile),
                        );
                      }
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.primaryContainer,
                        border: Border.all(
                          color: colorScheme.onSurface.withValues(alpha: 0.1),
                        ),
                      ),
                      child: ClipOval(
                        child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                            ? Image.network(
                                _resolveImageUrl(_avatarUrl)!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Text(
                                      _username.isNotEmpty
                                          ? _username[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Center(
                                child: Text(
                                  _username.isNotEmpty
                                      ? _username[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
