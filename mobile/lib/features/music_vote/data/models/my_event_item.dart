/// Model representing an event in the "My Events" dashboard.
///
/// Used for both the "Attending" and "Hosting" tab lists.
class MyEventItem {
  const MyEventItem({
    required this.id,
    required this.name,
    required this.hostName,
    required this.hostId,
    required this.dateTime,
    required this.status,
    this.coverImageAsset,
    this.coverColorHex = 0xFF7C3AED,
    this.listenerCount = 0,
    this.genre = '',
  });

  final String id;
  final String name;
  final String hostName;
  final String hostId;
  final DateTime dateTime;

  /// One of: 'LIVE', 'UPCOMING', 'ENDED'.
  final String status;

  /// Optional asset path for the event thumbnail.
  final String? coverImageAsset;

  /// Fallback color when no image is available.
  final int coverColorHex;

  /// Current listener count (only relevant for LIVE events).
  final int listenerCount;

  /// Genre tag for display.
  final String genre;

  bool get isLive => status == 'LIVE';
  bool get isUpcoming => status == 'UPCOMING';
  bool get isEnded => status == 'ENDED';
}
