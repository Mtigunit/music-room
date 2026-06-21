import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kDismissedKey = 'upgrade_snackbar_dismissed';

/// A persistent bottom banner encouraging BASIC users to upgrade to Premium.
///
/// Uses [SharedPreferences] to remember dismissal within the same app session.
/// Pass `visible = false` to hide regardless of stored state (e.g. after
/// upgrading).
class UpgradeReminderSnackbar extends StatefulWidget {
  const UpgradeReminderSnackbar({
    required this.visible,
    required this.onUpgrade,
    super.key,
  });

  final bool visible;
  final VoidCallback onUpgrade;

  @override
  State<UpgradeReminderSnackbar> createState() =>
      _UpgradeReminderSnackbarState();
}

class _UpgradeReminderSnackbarState extends State<UpgradeReminderSnackbar> {
  bool _dismissed = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDismissedState());
  }

  @override
  void didUpdateWidget(covariant UpgradeReminderSnackbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.visible && widget.visible) {
      unawaited(_resetDismissed());
    }
  }

  Future<void> _loadDismissedState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _dismissed = prefs.getBool(_kDismissedKey) ?? false;
      _loaded = true;
    });
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDismissedKey, true);
    if (mounted) {
      setState(() => _dismissed = true);
    }
  }

  Future<void> _resetDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDismissedKey);
    if (mounted) {
      setState(() => _dismissed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _dismissed || !widget.visible) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colorScheme.primary, colorScheme.secondary],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Upgrade to Premium to unlock all features.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: widget.onUpgrade,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text(
                  'Upgrade',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: _dismiss,
                icon: const Icon(Icons.close_rounded, size: 18),
                color: Colors.white,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
