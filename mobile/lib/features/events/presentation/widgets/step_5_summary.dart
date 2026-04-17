import 'package:flutter/material.dart';

class Step5Summary extends StatelessWidget {
  const Step5Summary({
    required this.eventName,
    required this.selectedGenres,
    required this.visibility,
    required this.votingRule,
    required this.trackCount,
    required this.invitedUsers,
    required this.onInvitesChanged,
    required this.onSubmit,
    super.key,
  });
  final String eventName;
  final List<String> selectedGenres;
  final String visibility;
  final String votingRule;
  final int trackCount;
  final List<String> invitedUsers;
  final ValueChanged<List<String>> onInvitesChanged;
  final VoidCallback onSubmit;

  void _addInvite(String username) {
    if (username.isNotEmpty && !invitedUsers.contains(username)) {
      final updated = List<String>.from(invitedUsers)..add(username);
      onInvitesChanged(updated);
    }
  }

  void _removeInvite(int index) {
    final updated = List<String>.from(invitedUsers)..removeAt(index);
    onInvitesChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Invite friends to join your room when it starts.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 24),

                // Invite Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: '@username or email',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    prefixIcon: Icon(
                      Icons.person_add_alt_1_outlined,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    suffixIcon: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.add,
                        color: theme.colorScheme.onPrimary,
                      ),
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
                  onSubmitted: _addInvite,
                ),
                const SizedBox(height: 16),

                // Display Invited Users (Chips)
                if (invitedUsers.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: invitedUsers.asMap().entries.map((entry) {
                      return Chip(
                        label: Text(entry.value),
                        onDeleted: () => _removeInvite(entry.key),
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        deleteIconColor: theme.colorScheme.error,
                        side: BorderSide.none,
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 32),

                // Room Summary Box
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ROOM SUMMARY',
                        style: theme.textTheme.labelMedium?.copyWith(
                          letterSpacing: 1.2,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSummaryRow(
                        'Name',
                        eventName.isEmpty ? 'Unnamed Room' : eventName,
                        theme,
                      ),
                      const Divider(height: 24),
                      _buildSummaryRow(
                        'Genres',
                        selectedGenres.isEmpty
                            ? 'None selected'
                            : selectedGenres.join(', '),
                        theme,
                      ),
                      const Divider(height: 24),
                      _buildSummaryRow(
                        'Visibility',
                        visibility,
                        theme,
                        valueColor: visibility == 'Public'
                            ? theme.colorScheme.tertiary
                            : theme.colorScheme.primary,
                      ),
                      const Divider(height: 24),
                      _buildSummaryRow(
                        'Voting',
                        votingRule,
                        theme,
                      ),
                      const Divider(height: 24),
                      _buildSummaryRow(
                        'Tracks queued',
                        '$trackCount',
                        theme,
                      ),
                      const Divider(height: 24),
                      _buildSummaryRow(
                        'Invited',
                        '${invitedUsers.length} friends',
                        theme,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
          child: ElevatedButton.icon(
            onPressed: onSubmit,
            icon: const Icon(Icons.video_call_outlined),
            label: const Text('Start Room'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 20),
              elevation: 4,
              shadowColor: theme.colorScheme.primary.withValues(alpha: 0.5),
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

  Widget _buildSummaryRow(
    String label,
    String value,
    ThemeData theme, {
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor ?? theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
