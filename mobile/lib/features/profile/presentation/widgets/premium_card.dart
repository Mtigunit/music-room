import 'package:flutter/material.dart';

/// A card that displays premium subscription features.
///
/// For BASIC users it shows an upgrade prompt with feature details.
/// For PREMIUM users it shows active feature checkmarks with a
/// downgrade option.
class PremiumCard extends StatelessWidget {
  const PremiumCard({
    required this.subscriptionTier,
    this.onUpgrade,
    this.onDowngrade,
    super.key,
  });

  final String subscriptionTier;
  final VoidCallback? onUpgrade;
  final VoidCallback? onDowngrade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isPremium = subscriptionTier.toUpperCase() == 'PREMIUM';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.secondary],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPremium ? 'Premium Active' : 'Premium Plan',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPremium
                          ? 'You have access to all premium features'
                          : 'Unlock the full Music Room experience',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (!isPremium) ...[
            const SizedBox(height: 20),
            // Premium features showcase
            PremiumFeatureTile(
              icon: Icons.block_rounded,
              title: 'Ad-Free Experience',
              description:
                  'Enjoy the app without any advertisements for a seamless '
                  'and distraction-free experience.',
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 12),
            PremiumFeatureTile(
              icon: Icons.how_to_vote_rounded,
              title: 'Unlimited Event Voting',
              description:
                  'Vote as many times as you want in all events and help '
                  'shape the outcomes that matter to you.',
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 12),
            PremiumFeatureTile(
              icon: Icons.playlist_add_rounded,
              title: 'Playlist Uploads for Events',
              description:
                  'Upload and share your own playlists with event organizers '
                  'and attendees to enhance the event experience.',
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 20),
            // Upgrade button
            UpgradeButton(onPressed: onUpgrade),
          ],

          if (isPremium) ...[
            const SizedBox(height: 16),
            // Premium active features
            ActiveFeatureRow(
              icon: Icons.block_rounded,
              label: 'Ad-Free Experience',
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 10),
            ActiveFeatureRow(
              icon: Icons.how_to_vote_rounded,
              label: 'Unlimited Event Voting',
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 10),
            ActiveFeatureRow(
              icon: Icons.playlist_add_rounded,
              label: 'Playlist Uploads for Events',
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 16),
            DowngradeButton(onPressed: onDowngrade),
          ],
        ],
      ),
    );
  }
}

class PremiumFeatureTile extends StatelessWidget {
  const PremiumFeatureTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.colorScheme,
    super.key,
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

class ActiveFeatureRow extends StatelessWidget {
  const ActiveFeatureRow({
    required this.icon,
    required this.label,
    required this.colorScheme,
    super.key,
  });

  final IconData icon;
  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.check_circle_rounded,
          size: 20,
          color: colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Icon(
          icon,
          size: 18,
          color: colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }
}

class UpgradeButton extends StatelessWidget {
  const UpgradeButton({this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      child: const Text(
        'Upgrade',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class DowngradeButton extends StatelessWidget {
  const DowngradeButton({this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.onSurface.withValues(alpha: 0.7),
        side: BorderSide(
          color: colorScheme.onSurface.withValues(alpha: 0.2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      child: const Text(
        'Downgrade',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
