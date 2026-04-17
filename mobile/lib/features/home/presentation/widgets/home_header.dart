import 'dart:async';

import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/app_scaffold.dart';
import 'package:music_room/features/home/presentation/widgets/notification_modal.dart';
import 'package:music_room/routes/route_names.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

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
              'Good evening',
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'djnova',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        Row(
          children: [
            GestureDetector(
              onTap: () {
                unawaited(
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    barrierColor: Colors.black.withValues(alpha: 0.8),
                    backgroundColor: Colors.transparent,
                    builder: (context) => const NotificationModal(),
                  ),
                );
              },
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorScheme.onSurface.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Icon(
                      Icons.notifications_none,
                      size: 24,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
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
              child: const CircleAvatar(
                radius: 20,
                backgroundImage: AssetImage('assets/images/step3.webp'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
