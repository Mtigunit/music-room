import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_room/core/widgets/app_snackbar.dart';
import 'package:music_room/core/widgets/confirmation_dialog.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/features/music_vote/data/models/event_delegated_user_model.dart';
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

  bool _isLoadingInvited = true;
  bool _isLoadingDelegated = true;
  String? _errorInvited;
  String? _errorDelegated;

  List<EventInvitedUserModel> _invitedUsers = const <EventInvitedUserModel>[];
  List<EventDelegatedUserModel> _delegatedUsers =
      const <EventDelegatedUserModel>[];

  // Keyed sets for individual user action states to support individual
  // loading indicators.
  final Set<String> _pendingDelegateIds = <String>{};
  final Set<String> _pendingRevokeIds = <String>{};
  final Set<String> _sentDelegateIds = <String>{};

  @override
  void initState() {
    super.initState();
    _repository = InjectionContainer().musicVoteRepository;
    unawaited(_loadData());
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingInvited = true;
      _isLoadingDelegated = true;
      _errorInvited = null;
      _errorDelegated = null;
    });

    await Future.wait([
      _loadInvitedUsers(),
      _loadDelegatedUsers(),
    ]);
  }

  Future<void> _loadInvitedUsers({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _isLoadingInvited = true;
        _errorInvited = null;
      });
    }

    try {
      final page = await _repository.getInvitedUsers(widget.eventId);
      if (!mounted) return;
      setState(() {
        _invitedUsers = page.users;
        _isLoadingInvited = false;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingInvited = false;
        _errorInvited = _readableError(error);
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isLoadingInvited = false;
        _errorInvited = 'Unable to load invited users.';
      });
    }
  }

  Future<void> _loadDelegatedUsers({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _isLoadingDelegated = true;
        _errorDelegated = null;
      });
    }

    try {
      final delegated = await _repository.getDelegatedUsers(widget.eventId);
      if (!mounted) return;
      setState(() {
        _delegatedUsers = delegated;
        _isLoadingDelegated = false;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingDelegated = false;
        _errorDelegated = _readableError(error);
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isLoadingDelegated = false;
        _errorDelegated = 'Unable to load delegated users.';
      });
    }
  }

  /// Filters out invited guests who are already delegated.
  List<EventInvitedUserModel> get _availableInvitedUsers {
    final delegatedIds = _delegatedUsers.map((u) => u.id).toSet();
    return _invitedUsers.where((u) => !delegatedIds.contains(u.id)).toList();
  }

  Future<void> _delegate(EventInvitedUserModel user) async {
    if (widget.hostId != null && widget.hostId == user.id) {
      AppSnackbar.showInfo(context, "You can't delegate yourself.");
      return;
    }
    if (_pendingDelegateIds.contains(user.id)) {
      return;
    }

    setState(() => _pendingDelegateIds.add(user.id));

    try {
      await _repository.createDelegation(widget.eventId, user.id);
      if (!mounted) return;
      setState(() {
        _pendingDelegateIds.remove(user.id);
        _sentDelegateIds.add(user.id);
      });
      AppSnackbar.showSuccess(
        context,
        'Delegation request sent to ${user.username}.',
      );
      unawaited(_loadDelegatedUsers(silent: true));
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() => _pendingDelegateIds.remove(user.id));
      AppSnackbar.showError(context, _readableError(error));
    } on Object {
      if (!mounted) return;
      setState(() => _pendingDelegateIds.remove(user.id));
      AppSnackbar.showError(
        context,
        'Could not delegate ${user.username}. Please try again.',
      );
    }
  }

  Future<void> _revokeDelegation(EventDelegatedUserModel user) async {
    if (_pendingRevokeIds.contains(user.id)) {
      return;
    }

    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'Remove Delegation',
      message:
          'Are you sure you want to remove playback delegation from '
          '${user.username}?',
      confirmLabel: 'Remove',
      icon: Icons.warning_amber_rounded,
      variant: ConfirmationDialogVariant.destructive,
    );

    if (confirmed != true) return;

    if (!mounted) return;
    setState(() => _pendingRevokeIds.add(user.id));

    try {
      await _repository.removeDelegation(widget.eventId, user.id);
      if (!mounted) return;
      setState(() {
        _pendingRevokeIds.remove(user.id);
        _sentDelegateIds.remove(user.id);
        // Instant local UI feedback
        _delegatedUsers = _delegatedUsers
            .where((u) => u.id != user.id)
            .toList();
      });
      AppSnackbar.showSuccess(
        context,
        'Delegation removed from ${user.username}.',
      );
      unawaited(_loadDelegatedUsers(silent: true));
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() => _pendingRevokeIds.remove(user.id));
      AppSnackbar.showError(context, _readableError(error));
    } on Object {
      if (!mounted) return;
      setState(() => _pendingRevokeIds.remove(user.id));
      AppSnackbar.showError(
        context,
        'Could not remove delegation for ${user.username}. Please try again.',
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

    final delegatedCount = _delegatedUsers.length;
    final memberCount = _invitedUsers.length;
    final isPageLoading = _isLoadingInvited && _isLoadingDelegated;
    final hasAnyError = _errorInvited != null || _errorDelegated != null;

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
                      isPageLoading
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
              if (!isPageLoading && !hasAnyError)
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
              if (!isPageLoading && !hasAnyError) const SizedBox(height: 12),

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
    if (_isLoadingInvited && _isLoadingDelegated) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorInvited != null) {
      return _ErrorState(
        message: _errorInvited!,
        onRetry: _loadData,
      );
    }
    if (_errorDelegated != null) {
      return _ErrorState(
        message: _errorDelegated!,
        onRetry: _loadData,
      );
    }

    final availableInvited = _availableInvitedUsers;
    final delegated = _delegatedUsers;

    if (availableInvited.isEmpty && delegated.isEmpty) {
      return const _EmptyState();
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      children: [
        if (delegated.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Row(
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'DELEGATED USERS (${delegated.length})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          ...delegated.map((user) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DelegatedUserRow(
                user: user,
                isPending: _pendingRevokeIds.contains(user.id),
                onRevoke: () => _revokeDelegation(user),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],

        if (availableInvited.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Row(
              children: [
                Icon(
                  Icons.group_add_rounded,
                  size: 16,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Text(
                  'INVITED USERS AVAILABLE FOR DELEGATION '
                  '(${availableInvited.length})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          ...availableInvited.map((user) {
            final isSelf = widget.hostId != null && widget.hostId == user.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DelegateUserRow(
                user: user,
                isHostSelf: isSelf,
                isPending: _pendingDelegateIds.contains(user.id),
                isDelegated: _sentDelegateIds.contains(user.id),
                onDelegate: () => _delegate(user),
              ),
            );
          }),
        ],

        // Show a compact empty helper block for delegated section if empty
        // but invited exists.
        if (delegated.isEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Row(
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  size: 16,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 6),
                Text(
                  'DELEGATED USERS (0)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          _DelegatedEmptyState(colorScheme: Theme.of(context).colorScheme),
          const SizedBox(height: 16),
        ],
      ],
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

class _DelegatedUserRow extends StatelessWidget {
  const _DelegatedUserRow({
    required this.user,
    required this.isPending,
    required this.onRevoke,
  });

  final EventDelegatedUserModel user;
  final bool isPending;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final rowBg = isDark
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
        : colorScheme.surface;
    final activeBorder = colorScheme.primary.withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          width: 1.5,
          color: activeBorder,
        ),
      ),
      child: Row(
        children: [
          _UserAvatar(
            username: user.username,
            avatarUrl: user.avatarUrl,
            primaryColor: colorScheme.primary,
            isDelegated: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.username,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Active',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Has playback controls permission',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
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
          _RevokeButton(
            isPending: isPending,
            onPressed: onRevoke,
          ),
        ],
      ),
    );
  }
}

class _RevokeButton extends StatelessWidget {
  const _RevokeButton({
    required this.isPending,
    required this.onPressed,
  });

  final bool isPending;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: TextButton(
        onPressed: isPending ? null : onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: isPending
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.error,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.remove_circle_outline_rounded,
                    size: 14,
                    color: colorScheme.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Remove',
                    style: TextStyle(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _DelegatedEmptyState extends StatelessWidget {
  const _DelegatedEmptyState({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.headset_off_rounded,
            color: colorScheme.onSurface.withValues(alpha: 0.35),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No users are currently delegated playback controls for this '
              'party.',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: isDelegated
            ? Border.all(
                color: colorScheme.primary.withValues(alpha: 0.4),
              )
            : null,
      ),
      child: TextButton(
        onPressed: disabled ? null : onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

        return Material(
          color: Colors.transparent,
          child: ListTile(
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
          ),
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
      final success = await cubit.endEvent(eventId);
      if (success && context.mounted) {
        Navigator.of(context).pop(); // close the delegation sheet
      }
    }
  }
}
