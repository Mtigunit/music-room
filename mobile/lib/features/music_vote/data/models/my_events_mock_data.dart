import 'package:music_room/features/music_vote/data/models/my_event_item.dart';

/// Mock data for the "My Events" dashboard.
///
/// Provides pre-built lists for the "Attending" and "Hosting" tabs.
class MyEventsMockData {
  // ── Attending ─────────────────────────────────────────────────────
  static final List<MyEventItem> attending = [
    MyEventItem(
      id: 'evt-att-001',
      name: 'Friday Night Vibes',
      hostName: 'djnova',
      hostId: 'user-001',
      dateTime: DateTime.now().subtract(
        const Duration(minutes: 12),
      ),
      status: 'LIVE',
      listenerCount: 247,
      genre: 'R&B',
    ),
    MyEventItem(
      id: 'evt-att-002',
      name: 'Sunset Lounge Mix',
      hostName: 'mellowbeats',
      hostId: 'user-002',
      dateTime: DateTime.now().add(const Duration(hours: 3)),
      status: 'UPCOMING',
      coverColorHex: 0xFFE67E22,
      genre: 'Chill',
    ),
    MyEventItem(
      id: 'evt-att-003',
      name: 'Late Night Classics',
      hostName: 'sara_jazz',
      hostId: 'user-003',
      dateTime: DateTime.now().add(const Duration(days: 2)),
      status: 'UPCOMING',
      coverColorHex: 0xFF2D6AC4,
      genre: 'Jazz',
    ),
    MyEventItem(
      id: 'evt-att-004',
      name: 'Weekend Warmup',
      hostName: 'trapking',
      hostId: 'user-004',
      dateTime: DateTime.now().subtract(const Duration(days: 1)),
      status: 'ENDED',
      coverColorHex: 0xFF1B9E77,
      genre: 'Hip-Hop',
    ),
  ];

  // ── Hosting ───────────────────────────────────────────────────────
  static final List<MyEventItem> hosting = [
    MyEventItem(
      id: 'evt-host-001',
      name: "Rachid's Party Room",
      hostName: 'You',
      hostId: 'user-rachid',
      dateTime: DateTime.now().subtract(const Duration(minutes: 5)),
      status: 'LIVE',
      coverColorHex: 0xFFE74C8B,
      listenerCount: 32,
      genre: 'Electronic',
    ),
    MyEventItem(
      id: 'evt-host-002',
      name: 'Chill Study Session',
      hostName: 'You',
      hostId: 'user-rachid',
      dateTime: DateTime.now().add(const Duration(days: 1, hours: 6)),
      status: 'UPCOMING',
      coverColorHex: 0xFF9B59B6,
      genre: 'Lo-Fi',
    ),
  ];
}
