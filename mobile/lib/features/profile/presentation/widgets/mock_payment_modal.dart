import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/app_button.dart';

/// Shows a mock payment confirmation bottom sheet for upgrading to Premium.
///
/// Returns `true` if the user confirms the mock payment, `null` otherwise.
Future<bool?> showMockPaymentModal(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _MockPaymentSheet(),
  );
}

class _MockPaymentSheet extends StatefulWidget {
  const _MockPaymentSheet();

  @override
  State<_MockPaymentSheet> createState() => _MockPaymentSheetState();
}

class _MockPaymentSheetState extends State<_MockPaymentSheet> {
  bool _isProcessing = false;

  Future<void> _handleConfirm() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    // Simulate a short payment processing delay.
    await Future<void>.delayed(const Duration(seconds: 2));

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),

              // Premium icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.secondary],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Upgrade to Premium',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),

              // Price
              Text(
                r'$9.99 / month',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),

              // Feature cards
              _PremiumFeatureCard(
                icon: Icons.block_rounded,
                title: 'Ad-Free Experience',
                description:
                    'Enjoy the app without any advertisements for a seamless '
                    'and distraction-free experience.',
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 10),
              _PremiumFeatureCard(
                icon: Icons.how_to_vote_rounded,
                title: 'Unlimited Event Voting',
                description:
                    'Vote as many times as you want in all events and help '
                    'shape the outcomes that matter to you.',
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 10),
              _PremiumFeatureCard(
                icon: Icons.playlist_add_rounded,
                title: 'Playlist Uploads for Events',
                description:
                    'Upload and share your own playlists with event organizers '
                    'and attendees to enhance the event experience.',
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 24),

              // Confirm button
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  onPressed: _isProcessing ? null : _handleConfirm,
                  label: _isProcessing ? 'Processing...' : 'Confirm Payment',
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 8),

              // Cancel button
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  onPressed: _isProcessing
                      ? null
                      : () => Navigator.of(context).pop(false),
                  variant: AppButtonVariant.outlined,
                  label: 'Cancel',
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumFeatureCard extends StatelessWidget {
  const _PremiumFeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.colorScheme,
  });

  final IconData icon;
  final String title;
  final String description;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.65),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
