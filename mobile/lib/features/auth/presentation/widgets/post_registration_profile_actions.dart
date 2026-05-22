import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/app_button.dart';
import 'package:music_room/features/auth/presentation/layouts/post_registration_profile_layout.dart';

class ProfileActionsWidget extends StatelessWidget {
  const ProfileActionsWidget({
    required this.layout,
    required this.isSaving,
    required this.isBusy,
    required this.onSave,
    required this.onSkip,
    super.key,
  });

  final ProfileLayout layout;
  final bool isSaving;
  final bool isBusy;
  final VoidCallback onSave;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    if (layout.isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton(
            onPressed: isBusy ? null : onSave,
            isLoading: isSaving,
            label: 'Save and continue',
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          SizedBox(height: layout.actionGap),
          AppButton(
            onPressed: isBusy ? null : onSkip,
            variant: AppButtonVariant.outlined,
            label: 'Skip for now',
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: AppButton(
            onPressed: isBusy ? null : onSave,
            isLoading: isSaving,
            label: 'Save and continue',
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        SizedBox(width: layout.actionGap),
        Expanded(
          child: AppButton(
            onPressed: isBusy ? null : onSkip,
            variant: AppButtonVariant.outlined,
            label: 'Skip for now',
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}
