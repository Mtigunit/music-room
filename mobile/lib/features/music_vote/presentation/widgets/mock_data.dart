/// Mock data models and hardcoded lists used exclusively for UI development.
/// Replace with real domain entities and repository calls in the next phase.
library;

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class MockTrack {
  const MockTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.colorHex,
    this.votes = 0,
    this.addedBy = '',
    this.rank = 0,
  });

  final int id;
  final String title;
  final String artist;
  final String album;
  final String duration;
  final int colorHex;
  final int votes;
  final String addedBy;
  final int rank;
}

class MockFriend {
  const MockFriend({
    required this.name,
    required this.username,
    required this.colorHex,
    this.isInvited = false,
  });

  final String name;
  final String username;
  final int colorHex;
  final bool isInvited;
}

// ---------------------------------------------------------------------------
// Delegation model
// ---------------------------------------------------------------------------

/// Represents a room member who can be granted DJ / playback-delegate rights.
class MockDelegateUser {
  const MockDelegateUser({
    required this.username,
    required this.colorHex,
    this.role = 'Voter',
    this.isPremium = false,
    this.isDelegated = false,
  });

  final String username;
  final int colorHex;

  /// Display role badge text, e.g. "DJ" or "Voter".
  final String role;

  /// Whether the user has a Premium badge.
  final bool isPremium;

  /// Whether playback control has been delegated to this user.
  final bool isDelegated;
}

// ---------------------------------------------------------------------------
// Queue tracks (Vote-ranked)
// ---------------------------------------------------------------------------

const List<MockTrack> mockQueueTracks = [
  MockTrack(
    id: 1,
    title: 'As It Was',
    artist: 'Harry Styles',
    album: "Harry's House",
    duration: '2:37',
    colorHex: 0xFF9B59B6,
    votes: 38,
    addedBy: 'Sofia',
    rank: 1,
  ),
  MockTrack(
    id: 2,
    title: 'Levitating',
    artist: 'Dua Lipa',
    album: 'Future Nostalgia',
    duration: '3:23',
    colorHex: 0xFF2D6AC4,
    votes: 29,
    addedBy: 'Marcus',
    rank: 2,
  ),
  MockTrack(
    id: 3,
    title: 'Stay',
    artist: 'The Kid LAROI & Justin…',
    album: 'F*CK LOVE 3',
    duration: '2:21',
    colorHex: 0xFF2D3A4A,
    votes: 21,
    addedBy: 'Lena',
    rank: 3,
  ),
  MockTrack(
    id: 4,
    title: 'Heat Waves',
    artist: 'Glass Animals',
    album: 'Dreamland',
    duration: '3:59',
    colorHex: 0xFF1B9E77,
    votes: 15,
    addedBy: 'Tom',
    rank: 4,
  ),
];

// ---------------------------------------------------------------------------
// Currently Playing
// ---------------------------------------------------------------------------

const MockTrack mockNowPlaying = MockTrack(
  id: 0,
  title: 'Blinding Lights',
  artist: 'The Weeknd',
  album: 'After Hours',
  duration: '3:30',
  colorHex: 0xFF7C3AED,
);

// ---------------------------------------------------------------------------
// Search result tracks (Add Song modal)
// ---------------------------------------------------------------------------

const List<MockTrack> mockSearchTracks = [
  MockTrack(
    id: 10,
    title: 'Flowers',
    artist: 'Miley Cyrus',
    album: 'Endless Summer Vacation',
    duration: '3:20',
    colorHex: 0xFFE74C8B,
  ),
  MockTrack(
    id: 11,
    title: 'Anti-Hero',
    artist: 'Taylor Swift',
    album: 'Midnights',
    duration: '3:20',
    colorHex: 0xFF1A1A2E,
  ),
  MockTrack(
    id: 12,
    title: 'Unholy',
    artist: 'Sam Smith ft. Kim Petras',
    album: 'Gloria',
    duration: '2:36',
    colorHex: 0xFF8B0000,
  ),
  MockTrack(
    id: 13,
    title: 'Calm Down',
    artist: 'Rema & Selena Gomez',
    album: 'Rave & Roses Ultra',
    duration: '3:59',
    colorHex: 0xFF16A085,
  ),
  MockTrack(
    id: 14,
    title: 'Cruel Summer',
    artist: 'Taylor Swift',
    album: 'Lover',
    duration: '2:58',
    colorHex: 0xFFD4A0D4,
  ),
  MockTrack(
    id: 15,
    title: 'Escapism.',
    artist: 'RAYE ft. 070 Shake',
    album: 'My 21st Century Blues',
    duration: '3:42',
    colorHex: 0xFF0A3D6B,
  ),
];

// ---------------------------------------------------------------------------
// Guest avatars (header overlapping avatars)
// ---------------------------------------------------------------------------

const List<int> mockGuestAvatarColors = [
  0xFF7C3AED,
  0xFFE74C8B,
  0xFF3498DB,
  0xFF2ECC71,
];

// ---------------------------------------------------------------------------
// Friends list (Invite modal)
// ---------------------------------------------------------------------------

const List<MockFriend> mockFriends = [
  MockFriend(
    name: 'Sofia Martinez',
    username: '@sofia_m',
    colorHex: 0xFF9B59B6,
  ),
  MockFriend(
    name: 'Marcus Johnson',
    username: '@marcus_j',
    colorHex: 0xFF3498DB,
  ),
  MockFriend(
    name: 'Lena Schmidt',
    username: '@lena_s',
    colorHex: 0xFF2ECC71,
    isInvited: true,
  ),
  MockFriend(
    name: 'Tom Williams',
    username: '@tomwill',
    colorHex: 0xFFE67E22,
  ),
  MockFriend(
    name: 'Aya Nakamura',
    username: '@aya_n',
    colorHex: 0xFFE74C8B,
  ),
];

// ---------------------------------------------------------------------------
// Delegation / Manage Room users
// ---------------------------------------------------------------------------

const List<MockDelegateUser> mockDelegateUsers = [
  MockDelegateUser(
    username: '@djnova',
    colorHex: 0xFF7C3AED,
    role: 'DJ',
    isPremium: true,
    isDelegated: true,
  ),
  MockDelegateUser(
    username: '@mellowbeats',
    colorHex: 0xFFE67E22,
    isPremium: true,
  ),
  MockDelegateUser(
    username: '@alex_m',
    colorHex: 0xFF3498DB,
  ),
  MockDelegateUser(
    username: '@sara_jazz',
    colorHex: 0xFFE74C8B,
  ),
  MockDelegateUser(
    username: '@trapking',
    colorHex: 0xFF2ECC71,
    isPremium: true,
  ),
  MockDelegateUser(
    username: '@aya_n',
    colorHex: 0xFF9B59B6,
  ),
];
