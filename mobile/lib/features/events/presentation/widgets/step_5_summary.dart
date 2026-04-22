import 'package:flutter/material.dart';

class Step5Summary extends StatelessWidget {
  const Step5Summary({
    required this.eventName,
    required this.selectedGenres,
    required this.visibility,
    required this.votingRule,
    required this.trackCount,
    required this.onSubmit,
    super.key,
  });

  final String eventName;
  final List<String> selectedGenres;
  final String visibility;
  final String votingRule;
  final int trackCount;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPublic = visibility.toLowerCase() == 'public';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Instructional headline
                Text(
                  'Review your event details before going live.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Hero Summary Card ──────────────────────────────────────
                _SummaryCard(
                  eventName: eventName,
                  selectedGenres: selectedGenres,
                  visibility: visibility,
                  isPublic: isPublic,
                  votingRule: votingRule,
                  trackCount: trackCount,
                ),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),

        // ── Start Event CTA ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
          child: ElevatedButton.icon(
            onPressed: onSubmit,
            icon: const Icon(Icons.play_circle_outline_rounded),
            label: const Text('Start Event'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 20),
              elevation: 6,
              shadowColor: theme.colorScheme.primary.withValues(alpha: 0.45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero Summary Card
// ---------------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.eventName,
    required this.selectedGenres,
    required this.visibility,
    required this.isPublic,
    required this.votingRule,
    required this.trackCount,
  });

  final String eventName;
  final List<String> selectedGenres;
  final String visibility;
  final bool isPublic;
  final String votingRule;
  final int trackCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surfaceContainerLow;
    final primaryTint = theme.colorScheme.primary.withValues(alpha: 0.06);

    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(primaryTint, cardColor),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.checklist_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'EVENT SUMMARY',
                  style: theme.textTheme.labelMedium?.copyWith(
                    letterSpacing: 1.4,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Rows
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              children: [
                _SummaryRow(
                  icon: Icons.label_outline_rounded,
                  label: 'Name',
                  value: eventName.isEmpty ? 'Unnamed Event' : eventName,
                ),
                _SummaryRow(
                  icon: Icons.music_note_rounded,
                  label: 'Genres',
                  value: selectedGenres.isEmpty
                      ? 'None selected'
                      : selectedGenres.join(', '),
                ),
                _SummaryRow(
                  icon: isPublic
                      ? Icons.public_rounded
                      : Icons.lock_outline_rounded,
                  label: 'Visibility',
                  value: visibility,
                ),
                _SummaryRow(
                  icon: Icons.how_to_vote_outlined,
                  label: 'Voting',
                  value: votingRule,
                ),
                _SummaryRow(
                  icon: Icons.queue_music_rounded,
                  label: 'Tracks queued',
                  value: trackCount.toString(),
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual Summary Row
// ---------------------------------------------------------------------------

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtleColor = theme.colorScheme.onSurface.withValues(alpha: 0.45);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              // Left: icon + label
              Icon(icon, size: 20, color: subtleColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: subtleColor,
                  ),
                ),
              ),
              // Right: value
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
      ],
    );
  }
}
