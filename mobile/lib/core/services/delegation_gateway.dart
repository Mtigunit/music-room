import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:music_room/core/realtime/socket_client.dart';
import 'package:music_room/core/realtime/socket_events.dart';

/// Payload carried by the `event:delegate` socket event.
@immutable
class DelegationInvite {
  const DelegationInvite({
    required this.eventId,
    required this.delegationId,
    required this.hostname,
    required this.eventName,
    this.delegateeId,
  });

  factory DelegationInvite.fromJson(Map<String, dynamic> json) {
    return DelegationInvite(
      eventId: (json['eventId'] as String? ?? '').trim(),
      delegationId: (json['delegationId'] as String? ?? '').trim(),
      hostname: (json['hostname'] as String? ?? '').trim(),
      eventName: (json['eventName'] as String? ?? '').trim(),
      delegateeId: (json['delegateeId'] as String?)?.trim(),
    );
  }

  final String eventId;
  final String delegationId;
  final String hostname;
  final String eventName;
  final String? delegateeId;

  bool get isValid => eventId.isNotEmpty && delegationId.isNotEmpty;
}

/// Centralised gateway for delegation socket events.
///
/// Mirrors `NotificationsService`: a singleton owned by `InjectionContainer`
/// that attaches a single `event:delegate` listener after auth, exposes a
/// broadcast stream consumed by UI overlays, and forwards user responses
/// back to the server via `event:delegation-response`.
///
/// All listener lifecycle is driven from `app.dart` (login → attach,
/// logout/disconnect → detach), so feature modules never need to wire the
/// socket themselves.
class DelegationGateway {
  DelegationGateway({required SocketClient socketClient})
    : _socketClient = socketClient;

  final SocketClient _socketClient;

  final StreamController<DelegationInvite> _incomingController =
      StreamController<DelegationInvite>.broadcast();
  final StreamController<DelegationInvite> _acceptedController =
      StreamController<DelegationInvite>.broadcast();

  /// Tracks delegationIds that the UI has already surfaced so the same
  /// invite is never re-shown if the server re-emits.
  final Set<String> _seenDelegationIds = <String>{};

  /// Maps `delegationId` → original invite payload, so listeners that only
  /// receive a `delegationId` (e.g. the popup) can still resolve the
  /// `eventId` after the user accepts.
  final Map<String, DelegationInvite> _invitesById =
      <String, DelegationInvite>{};

  bool _attached = false;

  /// Fires whenever a fresh `event:delegate` payload is received.
  Stream<DelegationInvite> get incomingInvites => _incomingController.stream;

  /// Fires after the local user accepts a delegation, once the
  /// `event:delegation-response` payload has been emitted. The matching
  /// invite is forwarded so consumers (e.g. `MusicVoteCubit`) can refresh
  /// the related event and unlock playback controls.
  Stream<DelegationInvite> get acceptedDelegations =>
      _acceptedController.stream;

  /// Attaches the socket listener (idempotent).
  void attachSocketListeners() {
    if (_attached) return;
    _socketClient.on(SocketEvent.delegate.value, _handleDelegate);
    _attached = true;
    if (kDebugMode) {
      debugPrint('🛂 [DelegationGateway] Attached event:delegate listener');
    }
  }

  /// Detaches the socket listener (idempotent).
  void detachSocketListeners() {
    if (!_attached) return;
    _socketClient.off(SocketEvent.delegate.value);
    _attached = false;
    _seenDelegationIds.clear();
    _invitesById.clear();
    if (kDebugMode) {
      debugPrint('🛂 [DelegationGateway] Detached event:delegate listener');
    }
  }

  /// Emits `event:delegation-response` for the given delegation.
  ///
  /// The backend handles activation server-side when `accept` is `true`.
  /// We always emit the response so the server can clean up its pending
  /// state regardless of accept/reject.
  void respond({required String delegationId, required bool accept}) {
    if (delegationId.isEmpty) return;
    if (!_socketClient.isConnected) {
      if (kDebugMode) {
        debugPrint(
          '🛂 [DelegationGateway] Skipped respond — socket not connected',
        );
      }
      // Even if the socket is not connected, drop the stored invite so the
      // map does not grow unbounded.
      _invitesById.remove(delegationId);
      return;
    }
    final payload = <String, dynamic>{
      'delegationId': delegationId,
      'accept': accept,
    };
    final eventName = SocketEvent.delegationResponse.value;
    _socketClient.emit(eventName, payload);
    if (kDebugMode) {
      debugPrint(
        '🚀 [DelegationGateway] Emitting: $eventName '
        'with payload: $payload',
      );
    }

    final invite = _invitesById.remove(delegationId);
    if (accept && invite != null) {
      _acceptedController.add(invite);
    }
  }

  /// Marks a delegationId as seen so the UI does not re-surface it. Useful
  /// when an overlay is already showing the invite locally.
  void markInviteHandled(String delegationId) {
    if (delegationId.isEmpty) return;
    _seenDelegationIds.add(delegationId);
  }

  void _handleDelegate(dynamic payload) {
    if (kDebugMode) {
      debugPrint('📡 [DelegationGateway] ← event:delegate $payload');
    }
    if (payload is! Map<String, dynamic>) return;

    final invite = DelegationInvite.fromJson(payload);
    if (!invite.isValid) return;

    // Deduplicate: the same delegation should never trigger two modals.
    if (!_seenDelegationIds.add(invite.delegationId)) {
      if (kDebugMode) {
        debugPrint(
          '🛂 [DelegationGateway] Duplicate invite ignored '
          '(delegationId=${invite.delegationId})',
        );
      }
      return;
    }

    _invitesById[invite.delegationId] = invite;
    _incomingController.add(invite);
  }

  Future<void> dispose() async {
    detachSocketListeners();
    await _incomingController.close();
    await _acceptedController.close();
  }
}
