import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/app_back_button.dart';
import 'package:music_room/core/widgets/responsive_layout.dart';

class ProfileEditHeader extends StatelessWidget {
  const ProfileEditHeader({
    required this.size,
    required this.showDragHandle,
    super.key,
  });

  final ScreenSize size;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = size == ScreenSize.expanded;
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isDesktop && showDragHandle)
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        Row(
          children: [
            if (isDesktop)
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: colorScheme.onSurface,
                ),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
              )
            else
              AppBackButton(
                color: colorScheme.onSurface,
                padding: EdgeInsets.zero,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Update your account, preferences, and security settings.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
