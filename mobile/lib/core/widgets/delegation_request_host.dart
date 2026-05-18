import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:music_room/core/services/delegation_gateway.dart';
import 'package:music_room/di/injection_container.dart';
import 'package:music_room/routes/app_router.dart';

/// Invisible widget that wraps the entire app and listens for incoming
/// `event:delegate` socket events from [DelegationGateway].
///
/// When a delegation invite arrives, it shows a modal bottom sheet with
/// Accept / Reject actions. The host enforces a single open modal at a
/// time so concurrent invites are queued.
class DelegationRequestHost extends StatefulWidget {
  const DelegationRequestHost({required this.child, super.key});

  final Widget child;

  @override
  State<DelegationRequestHost> createState() => _DelegationRequestHostState();
}

class _DelegationRequestHostState extends State<DelegationRequestHost> {
  StreamSubscription<DelegationInvite>? _subscription;
  bool _isShowingModal = false;
  final List<DelegationInvite> _pending = <DelegationInvite>[];

  @override
  void initState() {
    super.initState();
    _subscription = InjectionContainer().delegationGateway.incomingInvites
        .listen(_onIncomingInvite);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _onIncomingInvite(DelegationInvite invite) {
    if (!mounted) return;
    _pending.add(invite);
    unawaited(_drainQueue());
  }

  Future<void> _drainQueue() async {
    if (_isShowingModal) return;
    if (_pending.isEmpty) return;
    if (!mounted) return;

    final invite = _pending.removeAt(0);
    _isShowingModal = true;

    try {
      final accepted = await showModalBottomSheet<bool>(
        context: AppRouter.navigatorKey.currentContext ?? context,
        isScrollControlled: true,
        useSafeArea: true,
        useRootNavigator: true,
        isDismissible: false,
        enableDrag: false,
        barrierColor: Colors.black.withValues(alpha: 0.7),
        backgroundColor: Colors.transparent,
        builder: (_) => _DelegationRequestSheet(invite: invite),
      );

      // `null` (e.g. on a system back press while dismissible was true) is
      // treated as a rejection so the backend can clean up state.
      InjectionContainer().delegationGateway.respond(
        delegationId: invite.delegationId,
        accept: accepted ?? false,
      );
    } finally {
      _isShowingModal = false;
      if (mounted && _pending.isNotEmpty) {
        // Yield to the frame so the previous sheet finishes its exit
        // animation before we show the next one.
        unawaited(
          Future<void>.delayed(
            const Duration(milliseconds: 80),
            _drainQueue,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _DelegationRequestSheet extends StatelessWidget {
  const _DelegationRequestSheet({required this.invite});

  final DelegationInvite invite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final sheetBg = isDark ? const Color(0xFF15151F) : colorScheme.surface;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          curve: Curves.easeOutCubic,
          duration: const Duration(milliseconds: 280),
          builder: (context, t, child) {
            return Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, (1 - t) * 24),
                child: child,
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border(
                top: BorderSide(
                  color: colorScheme.primary.withValues(alpha: 0.25),
                ),
              ),
            ),
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 14,
              bottom: MediaQuery.paddingOf(context).bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DelegationHeader(
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
                const SizedBox(height: 10),
                _DelegationBodyText(
                  invite: invite,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
                const SizedBox(height: 26),
                _DelegationActionRow(
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DelegationHeader extends StatelessWidget {
  const _DelegationHeader({
    required this.colorScheme,
    required this.textTheme,
  });

  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle
        Center(
          child: Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 22),

        // Hero icon
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary,
                  colorScheme.primary.withValues(alpha: 0.6),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.headset_mic_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Title
        Text(
          'Delegation request',
          textAlign: TextAlign.center,
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
      ],
    );
  }
}

class _DelegationBodyText extends StatelessWidget {
  const _DelegationBodyText({
    required this.invite,
    required this.colorScheme,
    required this.textTheme,
  });

  final DelegationInvite invite;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final hostname = invite.hostname.isNotEmpty ? invite.hostname : 'The host';
    final eventName = invite.eventName.isNotEmpty
        ? invite.eventName
        : 'an event';

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.75),
          height: 1.45,
          fontSize: 15,
        ),
        children: <InlineSpan>[
          TextSpan(
            text: hostname,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const TextSpan(
            text: ' wants to give you music control for ',
          ),
          TextSpan(
            text: '“$eventName”',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const TextSpan(
            text: '. Accept to play, pause and skip tracks.',
          ),
        ],
      ),
    );
  }
}

class _DelegationActionRow extends StatelessWidget {
  const _DelegationActionRow({
    required this.colorScheme,
  });

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(
                color: colorScheme.onSurface.withValues(
                  alpha: 0.18,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              foregroundColor: colorScheme.onSurface.withValues(
                alpha: 0.85,
              ),
            ),
            child: const Text(
              'Reject',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Accept',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
