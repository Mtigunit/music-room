import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:music_room/features/events/domain/entities/event_location.dart';

// ---------------------------------------------------------------------------
// Step 4 – Access & Licenses
// ---------------------------------------------------------------------------

class Step4Access extends StatefulWidget {
  const Step4Access({
    required this.visibility,
    required this.votingRule,
    required this.isRestricted,
    required this.allowedLocation,
    required this.allowedRadius,
    required this.startDate,
    required this.startTime,
    required this.endDate,
    required this.endTime,
    required this.onVisibilityChanged,
    required this.onVotingRuleChanged,
    required this.onRestrictedChanged,
    required this.onLocationChanged,
    required this.onRadiusChanged,
    required this.onStartDateChanged,
    required this.onStartTimeChanged,
    required this.onEndDateChanged,
    required this.onEndTimeChanged,
    required this.onSubmit,
    required this.isSubmitting,
    super.key,
  });

  final String visibility;
  final String votingRule;
  final bool isRestricted;
  final EventLocation? allowedLocation;
  final double allowedRadius;
  final DateTime? startDate;
  final TimeOfDay? startTime;
  final DateTime? endDate;
  final TimeOfDay? endTime;

  final ValueChanged<String> onVisibilityChanged;
  final ValueChanged<String> onVotingRuleChanged;
  final ValueChanged<bool> onRestrictedChanged;
  final ValueChanged<EventLocation?> onLocationChanged;
  final ValueChanged<double> onRadiusChanged;
  final ValueChanged<DateTime?> onStartDateChanged;
  final ValueChanged<TimeOfDay?> onStartTimeChanged;
  final ValueChanged<DateTime?> onEndDateChanged;
  final ValueChanged<TimeOfDay?> onEndTimeChanged;
  final VoidCallback onSubmit;
  final bool isSubmitting;

  @override
  State<Step4Access> createState() => _Step4AccessState();
}

class _Step4AccessState extends State<Step4Access> {
  // ------------------------------------------------------------------
  // Map state
  // ------------------------------------------------------------------
  static const LatLng _defaultCenter = LatLng(48.8566, 2.3522); // Paris

  late final MapController _mapController;
  LatLng _centerPin = _defaultCenter;
  bool _locationLoading = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    // Seed pin from previously selected location, if any.
    if (widget.allowedLocation != null) {
      _centerPin = LatLng(
        widget.allowedLocation!.latitude,
        widget.allowedLocation!.longitude,
      );
    } else {
      // Attempt GPS fetch on first open.
      unawaited(_fetchGpsLocation());
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // GPS
  // ------------------------------------------------------------------
  Future<void> _fetchGpsLocation() async {
    setState(() => _locationLoading = true);

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      final latLng = LatLng(position.latitude, position.longitude);
      _mapController.move(latLng, 15);
      setState(() => _centerPin = latLng);
      widget.onLocationChanged(
        EventLocation(position.latitude, position.longitude),
      );
    } on Exception catch (_) {
      // Silently fall back to default center – not a fatal error.
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  // ------------------------------------------------------------------
  // Combined Date + Time picker
  // ------------------------------------------------------------------
  Future<void> _pickDateTime(
    BuildContext context, {
    required bool isStart,
  }) async {
    final now = DateTime.now();
    final existingDate = isStart ? widget.startDate : widget.endDate;
    final existingTime = isStart ? widget.startTime : widget.endTime;

    final initialDate = (existingDate != null && existingDate.isAfter(now))
        ? existingDate
        : now;

    // 1️⃣ Pick date first.
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (pickedDate == null || !mounted) return;

    // 2️⃣ Immediately open time picker, using the local context captured
    // before the async gap to satisfy the linter.
    if (!context.mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: existingTime ?? TimeOfDay.now(),
    );

    if (pickedTime == null || !mounted) return;

    // 3️⃣ Propagate both to parent.
    if (isStart) {
      widget.onStartDateChanged(pickedDate);
      widget.onStartTimeChanged(pickedTime);
    } else {
      widget.onEndDateChanged(pickedDate);
      widget.onEndTimeChanged(pickedTime);
    }
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  /// Builds a human-readable label: "Apr 23, 2026 • 04:30 PM" or a placeholder.
  String _formatDateTime(
    DateTime? date,
    TimeOfDay? time,
    String placeholder,
  ) {
    if (date == null) return placeholder;

    final datePart = DateFormat('MMM d, yyyy').format(date);
    if (time == null) return datePart;

    final dt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    return '$datePart • ${DateFormat('hh:mm a').format(dt)}';
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPrivate = widget.visibility == 'Private';
    final isEveryone = widget.votingRule == 'Everyone' && !isPrivate;
    final isInvitedOnly = widget.votingRule == 'Invited Only' || isPrivate;
    final showDynamicUI = widget.isRestricted;
    final radius = widget.allowedRadius.clamp(10.0, 500.0);

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

                // ── Visibility cards ──────────────────────────────────
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
                  onTap: () {
                    widget.onVisibilityChanged('Private');
                    if (widget.votingRule == 'Everyone') {
                      widget.onVotingRuleChanged('Invited Only');
                    }
                  },
                  theme: theme,
                ),
                const SizedBox(height: 20),

                // ── Voting permissions card ───────────────────────────
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

                      // Everyone can vote (Disabled when Private)
                      Opacity(
                        opacity: isPrivate ? 0.4 : 1.0,
                        child: _buildToggleRow(
                          title: 'Everyone can vote',
                          subtitle: 'All listeners can upvote tracks',
                          value: isEveryone,
                          onChanged: isPrivate
                              ? null
                              : (enabled) {
                                  if (enabled) {
                                    widget.onVotingRuleChanged('Everyone');
                                  } else {
                                    widget.onVotingRuleChanged('Invited Only');
                                  }
                                },
                          theme: theme,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Invited Only
                      _buildToggleRow(
                        title: 'Invited Only',
                        subtitle: 'Only explicitly invited users can vote',
                        value: isInvitedOnly,
                        onChanged: isPrivate
                            ? null
                            : (enabled) {
                                if (enabled) {
                                  widget.onVotingRuleChanged('Invited Only');
                                } else {
                                  widget.onVotingRuleChanged('Everyone');
                                }
                              },
                        theme: theme,
                      ),
                      const SizedBox(height: 14),

                      // Location & Time Restricted
                      _buildToggleRow(
                        title: 'Location & Time Restricted',
                        subtitle: 'Strict access requirements',
                        value: showDynamicUI,
                        onChanged: (enabled) {
                          widget.onRestrictedChanged(enabled);
                        },
                        theme: theme,
                      ),

                      // ── Dynamic section ───────────────────────────
                      if (showDynamicUI) ...[
                        const SizedBox(height: 20),
                        _buildMapSection(theme, radius),
                        const SizedBox(height: 16),
                        _buildDateTimeSection(theme),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),

        // ── Start Event button ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
          child: ElevatedButton(
            onPressed: widget.isSubmitting ? null : widget.onSubmit,
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
            child: widget.isSubmitting
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                : const Text('Start Event'),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Real FlutterMap + center-pin + CircleLayer
  // ------------------------------------------------------------------
  Widget _buildMapSection(ThemeData theme, double radius) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // -- Map container ------------------------------------------
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 250,
            child: Stack(
              children: [
                // Real OSM map
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _centerPin,
                    initialZoom: 15,
                    // Update pin & notify parent on every camera move.
                    onPositionChanged: (camera, hasGesture) {
                      if (!hasGesture) return;
                      setState(() => _centerPin = camera.center);
                      widget.onLocationChanged(
                        EventLocation(
                          camera.center.latitude,
                          camera.center.longitude,
                        ),
                      );
                    },
                  ),
                  children: [
                    // Free OSM tile layer – no API key required.
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.music_room.app',
                    ),
                    // Dynamic geofence circle.
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: _centerPin,
                          // radius in metres → flutter_map uses logical pixels
                          // at zoom 15: 1 metre ≈ 0.075 px, so keep as-is.
                          radius: radius,
                          useRadiusInMeter: true,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.18,
                          ),
                          borderColor: theme.colorScheme.primary,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                  ],
                ),

                // Static center-pin icon (always centered on the Stack).
                const Center(
                  child: _CenterPin(),
                ),

                // GPS button (top-right corner).
                Positioned(
                  top: 10,
                  right: 10,
                  child: _GpsButton(
                    loading: _locationLoading,
                    onPressed: _fetchGpsLocation,
                    theme: theme,
                  ),
                ),

                // Coordinates label (bottom-left corner).
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_centerPin.latitude.toStringAsFixed(5)}, '
                      '${_centerPin.longitude.toStringAsFixed(5)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontFeatures: const [],
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // -- Radius label -------------------------------------------
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Geofence Radius',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${radius.toInt()} m',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),

        // -- Radius slider ------------------------------------------
        Slider(
          value: widget.allowedRadius.clamp(10.0, 500.0),
          min: 10,
          max: 500,
          divisions: 49,
          label: '${radius.toInt()} m',
          activeColor: theme.colorScheme.primary,
          inactiveColor: theme.colorScheme.onSurface.withValues(alpha: 0.15),
          onChanged: widget.onRadiusChanged,
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Condensed 2-field date + time pickers
  // ------------------------------------------------------------------
  Widget _buildDateTimeSection(ThemeData theme) {
    return Column(
      children: [
        _buildPickerButton(
          context,
          label: _formatDateTime(
            widget.startDate,
            widget.startTime,
            'Start Date & Time',
          ),
          icon: Icons.play_circle_outline_rounded,
          isSet: widget.startDate != null,
          onTap: () => _pickDateTime(context, isStart: true),
          theme: theme,
        ),
        const SizedBox(height: 10),
        _buildPickerButton(
          context,
          label: _formatDateTime(
            widget.endDate,
            widget.endTime,
            'End Date & Time',
          ),
          icon: Icons.stop_circle_outlined,
          isSet: widget.endDate != null,
          onTap: () => _pickDateTime(context, isStart: false),
          theme: theme,
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Sub-widgets (unchanged helpers kept clean)
  // ------------------------------------------------------------------

  Widget _buildPickerButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isSet,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSet
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSet
                ? theme.colorScheme.primary.withValues(alpha: 0.6)
                : theme.colorScheme.onSurface.withValues(alpha: 0.2),
            width: isSet ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSet
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isSet
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  fontWeight: isSet ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
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
    required ValueChanged<bool>? onChanged,
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

// ---------------------------------------------------------------------------
// Private sub-widgets
// ---------------------------------------------------------------------------

/// Static pin icon always rendered at the center of the map stack.
class _CenterPin extends StatelessWidget {
  const _CenterPin();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: const Icon(Icons.place, color: Colors.white, size: 22),
        ),
        // Tiny pointer triangle below the circle.
        CustomPaint(
          size: const Size(12, 8),
          painter: _TrianglePainter(primary),
        ),
      ],
    );
  }
}

/// Draws a downward-pointing triangle for the pin's tail.
class _TrianglePainter extends CustomPainter {
  const _TrianglePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    // Use the dart:ui Path directly to avoid the latlong2 Path name clash.
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}

/// Floating GPS button shown in the top-right of the map.
class _GpsButton extends StatelessWidget {
  const _GpsButton({
    required this.loading,
    required this.onPressed,
    required this.theme,
  });

  final bool loading;
  final VoidCallback onPressed;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(10),
      elevation: 2,
      child: InkWell(
        onTap: loading ? null : onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: loading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                )
              : Icon(
                  Icons.my_location_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
        ),
      ),
    );
  }
}
