import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

class Step4Access extends StatefulWidget {
  const Step4Access({
    required this.visibility,
    required this.votingRule,
    required this.allowedLocation,
    required this.allowedRadius,
    required this.startDate,
    required this.startTime,
    required this.endDate,
    required this.endTime,
    required this.onVisibilityChanged,
    required this.onVotingRuleChanged,
    required this.onLocationChanged,
    required this.onRadiusChanged,
    required this.onStartDateChanged,
    required this.onStartTimeChanged,
    required this.onEndDateChanged,
    required this.onEndTimeChanged,
    required this.onNext,
    super.key,
  });
  final String visibility;
  final String votingRule;
  final LatLng? allowedLocation;
  final double allowedRadius;
  final DateTime? startDate;
  final TimeOfDay? startTime;
  final DateTime? endDate;
  final TimeOfDay? endTime;

  final ValueChanged<String> onVisibilityChanged;
  final ValueChanged<String> onVotingRuleChanged;
  final ValueChanged<LatLng?> onLocationChanged;
  final ValueChanged<double> onRadiusChanged;
  final ValueChanged<DateTime?> onStartDateChanged;
  final ValueChanged<TimeOfDay?> onStartTimeChanged;
  final ValueChanged<DateTime?> onEndDateChanged;
  final ValueChanged<TimeOfDay?> onEndTimeChanged;
  final VoidCallback onNext;

  @override
  State<Step4Access> createState() => _Step4AccessState();
}

class _Step4AccessState extends State<Step4Access> {
  Future<void> _pickDate(BuildContext context, {required bool isStart}) async {
    final now = DateTime.now();
    final current = isStart ? widget.startDate : widget.endDate;
    final initialDate = (current != null && current.isAfter(now))
        ? current
        : now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked == null) {
      return;
    }

    if (isStart) {
      widget.onStartDateChanged(picked);
    } else {
      widget.onEndDateChanged(picked);
    }
  }

  Future<void> _pickTime(BuildContext context, {required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (widget.startTime ?? TimeOfDay.now())
          : (widget.endTime ?? TimeOfDay.now()),
    );

    if (picked == null) {
      return;
    }

    if (isStart) {
      widget.onStartTimeChanged(picked);
    } else {
      widget.onEndTimeChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showDynamicUI = widget.votingRule == 'Location & Time';
    final mockRadius = widget.allowedRadius.clamp(10.0, 250.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Control who can join and interact in your event.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSelectionCard(
                  title: 'Public',
                  subtitle: 'Anyone can discover and join your event',
                  icon: Icons.public,
                  isSelected: widget.visibility == 'Public',
                  onTap: () => widget.onVisibilityChanged('Public'),
                  theme: theme,
                ),
                const SizedBox(height: 12),
                _buildSelectionCard(
                  title: 'Private',
                  subtitle: 'Only people with an invite link can join',
                  icon: Icons.lock_outline,
                  isSelected: widget.visibility == 'Private',
                  onTap: () => widget.onVisibilityChanged('Private'),
                  theme: theme,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VOTING PERMISSIONS',
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _buildToggleRow(
                        title: 'Everyone can vote',
                        subtitle: 'All listeners can upvote tracks',
                        value: widget.votingRule == 'Everyone',
                        onChanged: (enabled) {
                          if (enabled) {
                            widget.onVotingRuleChanged('Everyone');
                          }
                        },
                        theme: theme,
                      ),
                      const SizedBox(height: 14),
                      _buildToggleRow(
                        title: 'Invited Only',
                        subtitle: 'Only explicitly invited users can vote',
                        value: widget.votingRule == 'Invited Only',
                        onChanged: (enabled) {
                          if (enabled) {
                            widget.onVotingRuleChanged('Invited Only');
                          }
                        },
                        theme: theme,
                      ),
                      const SizedBox(height: 14),
                      _buildToggleRow(
                        title: 'Location & Time Restricted',
                        subtitle: 'Strict access requirements',
                        value: showDynamicUI,
                        onChanged: (enabled) {
                          widget.onVotingRuleChanged(
                            enabled ? 'Location & Time' : 'Everyone',
                          );
                        },
                        theme: theme,
                      ),
                      if (showDynamicUI) ...[
                        const SizedBox(height: 18),
                        _buildMockMap(theme, mockRadius),
                        const SizedBox(height: 10),
                        Text(
                          'Mock Radius: ${mockRadius.toInt()}m',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.75,
                            ),
                          ),
                        ),
                        Slider(
                          value: mockRadius,
                          min: 10,
                          max: 250,
                          divisions: 24,
                          label: '${mockRadius.toInt()}m',
                          activeColor: theme.colorScheme.primary,
                          inactiveColor: theme.colorScheme.onSurface.withValues(
                            alpha: 0.15,
                          ),
                          onChanged: widget.onRadiusChanged,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: _buildPickerButton(
                                context,
                                label: widget.startDate == null
                                    ? 'Start Date'
                                    : DateFormat(
                                        'MMM d, yyyy',
                                      ).format(widget.startDate!),
                                icon: Icons.calendar_today_outlined,
                                onTap: () => _pickDate(context, isStart: true),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildPickerButton(
                                context,
                                label: widget.startTime == null
                                    ? 'Start Time'
                                    : widget.startTime!.format(context),
                                icon: Icons.schedule_outlined,
                                onTap: () => _pickTime(context, isStart: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildPickerButton(
                                context,
                                label: widget.endDate == null
                                    ? 'End Date'
                                    : DateFormat(
                                        'MMM d, yyyy',
                                      ).format(widget.endDate!),
                                icon: Icons.calendar_today_outlined,
                                onTap: () => _pickDate(context, isStart: false),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildPickerButton(
                                context,
                                label: widget.endTime == null
                                    ? 'End Time'
                                    : widget.endTime!.format(context),
                                icon: Icons.schedule_outlined,
                                onTap: () => _pickTime(context, isStart: false),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
          child: ElevatedButton(
            onPressed: widget.onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Continue'),
          ),
        ),
      ],
    );
  }

  Widget _buildMockMap(ThemeData theme, double radius) {
    final normalized = (radius - 10) / 240;
    final circleSize = 44 + (normalized * 90);

    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              border: Border.all(color: theme.colorScheme.primary, width: 2),
            ),
          ),
          Icon(
            Icons.place,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          Positioned(
            left: 16,
            top: 12,
            child: Text(
              'Mock map preview',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.15),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.65,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: theme.colorScheme.onPrimary,
          activeTrackColor: theme.colorScheme.primary,
          inactiveThumbColor: theme.colorScheme.onSurface.withValues(
            alpha: 0.5,
          ),
          inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
        ),
      ],
    );
  }
}
