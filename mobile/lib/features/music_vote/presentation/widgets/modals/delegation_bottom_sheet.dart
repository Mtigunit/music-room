import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/core/widgets/confirmation_dialog.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/music_vote/data/models/event_invited_user_model.dart';
import 'package:music_room/features/music_vote/domain/repositories/music_vote_repository.dart';
import 'package:music_room/features/music_vote/presentation/state/music_vote_cubit.dart';

/// "Manage Room & Delegation" bottom sheet.
///
/// • Lists the host's invited users (from `GET /events/{id}/invited`).
/// • Each row shows avatar + username and a Delegate button that calls
///   `POST /events/{id}/delegations`.
/// • Prevents delegating the host to themselves and disables the button
///   once a delegation request has been sent for that user.
/// • Includes the existing End Event action at the top of the sheet.
class DelegationBottomSheet extends StatefulWidget {
  const DelegationBottomSheet({
    required this.eventId,
    super.key,
    this.eventName,
    this.hostId,
  });

  final String eventId;
  final String? eventName;
  final String? hostId;

  @override
  State<DelegationBottomSheet> createState() => _DelegationBottomSheetState();
}

class _DelegationBottomSheetState extends State<DelegationBottomSheet> {
  late final MusicVoteRepository _repository;

  bool _isLoading = true;
  String? _error;
  List<EventInvitedUserModel> _users = const <EventInvitedUserModel>[];
  // Local "pending" / "sent" flags keyed by user id so the UI doesn't fire
  // two delegation requests for the same user and gives feedback while the
  // POST is in flight.
  final Set<String> _pendingIds = <String>{};
  final Set<String> _delegatedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _repository = InjectionContainer().musicVoteRepository;
    unawaited(_loadInvitedUsers());
  }

  Future<void> _loadInvitedUsers() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final page = await _repository.getInvitedUsers(widget.eventId);
      if (!mounted) return;
      setState(() {
        _users = page.users;
        _isLoading = false;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _readableError(error);
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Unable to load invited users.';
      });
    }
  }

  Future<void> _delegate(EventInvitedUserModel user) async {
    // Defensive: prevent host from delegating themselves and prevent dupes.
    if (widget.hostId != null && widget.hostId == user.id) {
      AppSnackbar.showInfo(context, "You can't delegate yourself.");
      return;
    }
    if (_pendingIds.contains(user.id) || _delegatedIds.contains(user.id)) {
      return;
    }

    setState(() => _pendingIds.add(user.id));

    try {
      await _repository.createDelegation(widget.eventId, user.id);
      if (!mounted) return;
      setState(() {
        _pendingIds.remove(user.id);
        _delegatedIds.add(user.id);
      });
      AppSnackbar.showSuccess(
        context,
        'Delegation request sent to ${user.username}.',
      );
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() => _pendingIds.remove(user.id));
      AppSnackbar.showError(context, _readableError(error));
    } on Object {
      if (!mounted) return;
      setState(() => _pendingIds.remove(user.id));
      AppSnackbar.showError(
        context,
        'Could not delegate ${user.username}. Please try again.',
      );
    }
  }

  String _readableError(DioException error) {
    final apiMessage = _extractApiMessage(error.response?.data);
    if (apiMessage != null && apiMessage.isNotEmpty) {
      return apiMessage;
    }
    switch (error.response?.statusCode) {
      case 400:
        return 'Invalid delegation request.';
      case 401:
        return 'Your session expired. Please sign in again.';
      case 403:
        return 'Only the host can delegate music control.';
      case 404:
        return 'Event or user not found.';
      case 409:
        return 'This user already has an active delegation.';
      default:
        if (error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.sendTimeout) {
          return 'Network issue. Please try again.';
        }
        return 'Something went wrong. Please try again.';
    }
  }

  String? _extractApiMessage(Object? data) {
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
      if (message is List<dynamic>) {
        final joined = message
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .join('\n');
        if (joined.isNotEmpty) return joined;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF151520) : colorScheme.surface;

    final delegatedCount = _delegatedIds.length;
    final memberCount = _users.length;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // End Event tile (destructive, top of the sheet)
              _EndEventTile(eventId: widget.eventId),

              const Divider(indent: 20, endIndent: 20, height: 1),
              const SizedBox(height: 16),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Delegation',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isLoading
                          ? 'Loading invited users…'
                          : memberCount == 0
                          ? 'No one to delegate yet'
                          : '${widget.eventName ?? 'This event'} · '
                                '$memberCount invited',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Info banner
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _InfoBanner(
                  colorScheme: colorScheme,
                  isDark: isDark,
                ),
              ),
              const SizedBox(height: 16),

              // Stats
              if (!_isLoading && _error == null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _StatsRow(
                    delegatedCount: delegatedCount,
                    remaining: (memberCount - delegatedCount).clamp(
                      0,
                      memberCount,
                    ),
                    total: memberCount,
                    colorScheme: colorScheme,
                    isDark: isDark,
                  ),
                ),
              if (!_isLoading && _error == null) const SizedBox(height: 12),

              // Body: loading / error / empty / list
              Expanded(child: _buildBody(scrollController)),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(ScrollController scrollController) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _loadInvitedUsers);
    }
    if (_users.isEmpty) {
      return const _EmptyState();
    }
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      itemCount: _users.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final user = _users[index];
        final isSelf = widget.hostId != null && widget.hostId == user.id;
        return _DelegateUserRow(
          user: user,
          isHostSelf: isSelf,
          isPending: _pendingIds.contains(user.id),
          isDelegated: _delegatedIds.contains(user.id),
          onDelegate: () => _delegate(user),
        );
      },
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ───────────────────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.colorScheme, required this.isDark});

  final ColorScheme colorScheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bannerBg = isDark
        ? colorScheme.primary.withValues(alpha: 0.12)
        : colorScheme.primary.withValues(alpha: 0.06);
    final textColor = isDark
        ? colorScheme.onSurface.withValues(alpha: 0.85)
        : colorScheme.primary.withValues(alpha: 0.9);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Delegated users can play, pause and skip tracks while the '
              'event is live. Send a request and they will be prompted to '
              'accept on their device.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.delegatedCount,
    required this.remaining,
    required this.total,
    required this.colorScheme,
    required this.isDark,
  });

  final int delegatedCount;
  final int remaining;
  final int total;
  final ColorScheme colorScheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.04);

    Widget stat(String value, String label) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.onSurface.withValues(alpha: 0.07),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.primary,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        stat('$delegatedCount', 'Sent'),
        const SizedBox(width: 10),
        stat('$remaining', 'Remaining'),
        const SizedBox(width: 10),
        stat('$total', 'Invited'),
      ],
    );
  }
}

class _DelegateUserRow extends StatelessWidget {
  const _DelegateUserRow({
    required this.user,
    required this.isHostSelf,
    required this.isPending,
    required this.isDelegated,
    required this.onDelegate,
  });

  final EventInvitedUserModel user;
  final bool isHostSelf;
  final bool isPending;
  final bool isDelegated;
  final VoidCallback onDelegate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final rowBg = isDark
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
        : colorScheme.surface;
    final delegatedBorder = colorScheme.primary.withValues(alpha: 0.4);
    final neutralBorder = colorScheme.onSurface.withValues(alpha: 0.08);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          width: isDelegated ? 1.5 : 1,
          color: isDelegated ? delegatedBorder : neutralBorder,
        ),
      ),
      child: Row(
        children: [
          _UserAvatar(
            username: user.username,
            avatarUrl: user.avatarUrl,
            primaryColor: colorScheme.primary,
            isDelegated: isDelegated,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.username,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  isHostSelf
                      ? 'You (host)'
                      : isDelegated
                      ? 'Delegation request sent'
                      : 'Invited guest',
                  style: textTheme.bodySmall?.copyWith(
                    color: isDelegated
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _DelegateButton(
            isHostSelf: isHostSelf,
            isPending: isPending,
            isDelegated: isDelegated,
            onPressed: onDelegate,
          ),
        ],
      ),
    );
  }
}

class _DelegateButton extends StatelessWidget {
  const _DelegateButton({
    required this.isHostSelf,
    required this.isPending,
    required this.isDelegated,
    required this.onPressed,
  });

  final bool isHostSelf;
  final bool isPending;
  final bool isDelegated;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final disabled = isHostSelf || isPending || isDelegated;
    final bg = isDelegated
        ? colorScheme.primary.withValues(alpha: 0.15)
        : (disabled
              ? colorScheme.onSurface.withValues(alpha: 0.08)
              : colorScheme.primary);
    final fg = isDelegated
        ? colorScheme.primary
        : (disabled
              ? colorScheme.onSurface.withValues(alpha: 0.45)
              : Colors.white);
    final label = isHostSelf
        ? 'You'
        : isDelegated
        ? 'Sent ✓'
        : 'Delegate';

    return GestureDetector(
      onTap: disabled ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: isDelegated
              ? Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.4),
                )
              : null,
        ),
        child: isPending
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({
    required this.username,
    required this.avatarUrl,
    required this.primaryColor,
    required this.isDelegated,
  });

  final String username;
  final String? avatarUrl;
  final Color primaryColor;
  final bool isDelegated;

  @override
  Widget build(BuildContext context) {
    final initial = username.trim().isEmpty
        ? '?'
        : username.trim().substring(0, 1).toUpperCase();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _colorFromSeed(username),
            border: isDelegated
                ? Border.all(color: primaryColor, width: 2)
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: avatarUrl != null && avatarUrl!.isNotEmpty
              ? Image.network(
                  avatarUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _initial(initial),
                )
              : _initial(initial),
        ),
        if (isDelegated)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.headset_mic_rounded,
                size: 10,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _initial(String initial) {
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
    );
  }

  Color _colorFromSeed(String seed) {
    const fnvPrime = 0x01000193;
    var hash = 0x811C9DC5;
    for (final codeUnit in seed.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    final red = 100 + (hash & 0x3F);
    final green = 100 + ((hash >> 8) & 0x3F);
    final blue = 100 + ((hash >> 16) & 0x3F);
    return Color(0xFF000000 | (red << 16) | (green << 8) | blue);
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 42,
              color: colorScheme.error.withValues(alpha: 0.75),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.group_add_outlined,
              size: 42,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No invited users yet',
              textAlign: TextAlign.center,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Invite friends to your event first, then come back here '
              'to delegate music controls to them.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.55),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EndEventTile extends StatelessWidget {
  const _EndEventTile({required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return BlocConsumer<MusicVoteCubit, MusicVoteState>(
      listenWhen: (prev, curr) =>
          prev.isEndingEvent && !curr.isEndingEvent && curr.error != null,
      listener: (context, state) {
        if (state.error != null) {
          AppSnackbar.showError(context, state.error!);
        }
      },
      buildWhen: (prev, curr) => prev.isEndingEvent != curr.isEndingEvent,
      builder: (context, state) {
        final isDisabled = eventId.isEmpty || state.isEndingEvent;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: state.isEndingEvent
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.red,
                  ),
                )
              : Icon(
                  Icons.stop_circle,
                  color: isDisabled ? Colors.grey : Colors.red,
                ),
          title: Text(
            'End Event',
            style: textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDisabled ? Colors.grey : Colors.red,
            ),
          ),
          subtitle: Text(
            'Stop the event and end all playback',
            style: textTheme.bodySmall?.copyWith(
              color: isDisabled
                  ? Colors.grey.withValues(alpha: 0.6)
                  : Colors.red.withValues(alpha: 0.6),
            ),
          ),
          onTap: isDisabled ? null : () => _showEndConfirmation(context),
        );
      },
    );
  }

  Future<void> _showEndConfirmation(BuildContext context) async {
    if (!context.mounted) return;

    final cubit = context.read<MusicVoteCubit>();

    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'End event',
      message:
          'Are you sure you want to end this event? '
          'This will stop all playback and the event will be '
          'marked as ended. This action cannot be undone.',
      confirmLabel: 'End event',
      icon: Icons.warning_amber_rounded,
      variant: ConfirmationDialogVariant.destructive,
    );

    if (confirmed == true && context.mounted) {
      await cubit.endEvent(eventId);
      if (context.mounted) {
        Navigator.of(context).pop(); // close the delegation sheet
      }
    }
  }
}
