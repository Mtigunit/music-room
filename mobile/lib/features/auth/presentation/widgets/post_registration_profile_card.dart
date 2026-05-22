import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:music_room/features/auth/presentation/layouts/post_registration_profile_layout.dart';

class ProfileCardWidget extends StatelessWidget {
  const ProfileCardWidget({
    required this.layout,
    required this.theme,
    required this.avatarUrl,
    required this.pickedAvatarBytes,
    required this.pickedAvatarName,
    required this.isUploadingAvatar,
    required this.onTap,
    super.key,
  });

  final ProfileLayout layout;
  final ThemeData theme;
  final String? avatarUrl;
  final Uint8List? pickedAvatarBytes;
  final String? pickedAvatarName;
  final bool isUploadingAvatar;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    ImageProvider<Object>? avatarImage;

    if (pickedAvatarBytes != null) {
      avatarImage = MemoryImage(pickedAvatarBytes!);
    } else if (avatarUrl != null) {
      avatarImage = NetworkImage(avatarUrl!);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(layout.cardRadius),
      child: Container(
        padding: EdgeInsets.all(layout.cardPadding),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(layout.cardRadius),
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: layout.avatarRadius,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
              backgroundImage: avatarImage,
              child: isUploadingAvatar
                  ? SizedBox(
                      width: layout.avatarLoaderSize,
                      height: layout.avatarLoaderSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.primary,
                        ),
                      ),
                    )
                  : (avatarImage == null
                        ? Icon(
                            Icons.add_a_photo_rounded,
                            color: colorScheme.primary,
                            size: layout.avatarIconSize,
                          )
                        : null),
            ),
            SizedBox(width: layout.cardInnerGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile photo',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: layout.sectionTitleFontSize,
                    ),
                  ),
                  SizedBox(height: layout.cardCopyGap),
                  Text(
                    pickedAvatarName != null
                        ? 'Photo selected: $pickedAvatarName'
                        : (avatarUrl != null
                              ? 'Photo uploaded'
                              : 'Tap to add a photo later from your profile.'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: layout.bodyFontSize,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: layout.cardInnerGap),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
              size: layout.chevronSize,
            ),
          ],
        ),
      ),
    );
  }
}
