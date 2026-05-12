import 'dart:async';

import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/app_scaffold.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/home/presentation/widgets/show_notification_panel.dart';
import 'package:music_room/routes/route_names.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    this.greeting = 'Good evening',
    this.username = 'djnova',
  });

  final String greeting;
  final String username;

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
              greeting,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              username,
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
                    initialData: 0,
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
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: CircleAvatar(
                          radius: 20,
                          backgroundImage: AssetImage(
                            'assets/images/step3.webp',
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
