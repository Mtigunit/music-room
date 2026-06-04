import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:music_room/core/config/app_config.dart';
import 'package:music_room/core/widgets/responsive_layout.dart';
import 'package:music_room/features/events/presentation/widgets/image_helper/image_helper.dart';

class Step1Details extends StatelessWidget {
  const Step1Details({
    required this.eventName,
    required this.eventDescription,
    required this.eventCover,
    required this.scheduledStartTime,
    required this.onNameChanged,
    required this.onDescriptionChanged,
    required this.onCoverChanged,
    required this.onScheduledStartTimeChanged,
    required this.canContinue,
    required this.onNext,
    this.nameError,
    this.initialImageUrl,
    super.key,
  });
  final String eventName;
  final String eventDescription;
  final XFile? eventCover;
  final DateTime scheduledStartTime;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onDescriptionChanged;
  final ValueChanged<XFile?> onCoverChanged;
  final ValueChanged<DateTime> onScheduledStartTimeChanged;
  final bool canContinue;
  final String? nameError;
  final String? initialImageUrl;
  final VoidCallback onNext;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      onCoverChanged(pickedFile);
    }
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: scheduledStartTime,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      if (!context.mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(scheduledStartTime),
      );

      if (time != null) {
        onScheduledStartTimeChanged(
          DateTime(date.year, date.month, date.day, time.hour, time.minute),
        );
      }
    }
  }

  ImageProvider _getCoverImage() {
    if (eventCover != null) {
      return getPlatformCoverImage(eventCover!);
    }
    if (initialImageUrl != null && initialImageUrl!.isNotEmpty) {
      // In a real app we might use CachedNetworkImageProvider,
      // but NetworkImage is fine here.
      final isAbsolute = initialImageUrl!.startsWith('http');
      final relPath = initialImageUrl!.startsWith('/')
          ? initialImageUrl!.substring(1)
          : initialImageUrl!;
      final fullUrl = isAbsolute
          ? initialImageUrl!
          : '${AppConfig.apiBaseUrl}$relPath';
      return NetworkImage(fullUrl);
    }
    return const AssetImage('assets/images/step1.webp');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final size = ResponsiveLayout.resolveSize(width);
    final isCompact = size == ScreenSize.compact;
    final horizontalPadding = isCompact ? 16.0 : 24.0;
    final sectionSpacing = isCompact ? 20.0 : 24.0;
    final fieldVerticalPadding = isCompact ? 14.0 : 16.0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'EVENT NAME',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: eventName,
            onChanged: onNameChanged,
            decoration: InputDecoration(
              hintText: 'e.g. Late Night Vibes',
              errorText: nameError,
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(
                    alpha: 0.1,
                  ),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: theme.colorScheme.primary),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: fieldVerticalPadding,
              ),
            ),
          ),
          SizedBox(height: sectionSpacing),

          Text(
            'DESCRIPTION (OPTIONAL)',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: eventDescription,
            onChanged: onDescriptionChanged,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: "What's the vibe?",
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(
                    alpha: 0.1,
                  ),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: theme.colorScheme.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'EVENT DATE & TIME',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _selectDateTime(context),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: fieldVerticalPadding,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(
                    alpha: 0.1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('EEEE, MMM d · hh:mm a').format(
                      scheduledStartTime,
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_drop_down,
                    color: theme.colorScheme.onSurface.withValues(
                      alpha: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'EVENT COVER',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: isCompact ? 160 : 180,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(
                    alpha: 0.1,
                  ),
                ),
                image: DecorationImage(
                  image: _getCoverImage(),
                  fit: BoxFit.cover,
                  colorFilter: eventCover == null
                      ? ColorFilter.mode(
                          Colors.black.withValues(alpha: 0.3),
                          BlendMode.darken,
                        )
                      : null,
                ),
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(
                      alpha: 0.8,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        eventCover == null ? 'Add Event Cover' : 'Change Cover',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: isCompact ? 24 : 32),

          ElevatedButton(
            onPressed: canContinue ? onNext : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              disabledBackgroundColor: theme.colorScheme.onSurface.withValues(
                alpha: 0.12,
              ),
              foregroundColor: theme.colorScheme.onPrimary,
              disabledForegroundColor: theme.colorScheme.onSurface.withValues(
                alpha: 0.38,
              ),
              padding: EdgeInsets.symmetric(vertical: isCompact ? 14 : 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: const Text('Continue'),
          ),
          SizedBox(height: isCompact ? 24 : 32),
        ],
      ),
    );
  }
}
