/// Backend playlist tag enum matching Prisma schema.
enum PlaylistTag {
  pop('POP'),
  hipHop('HIP_HOP'),
  rnb('RNB'),
  rock('ROCK'),
  jazz('JAZZ'),
  classical('CLASSICAL'),
  electronic('ELECTRONIC'),
  country('COUNTRY'),
  chill('CHILL'),
  workout('WORKOUT'),
  party('PARTY'),
  focus('FOCUS'),
  acoustic('ACOUSTIC')
  ;

  const PlaylistTag(this.value);

  final String value;

  /// Get the display label for this tag.
  String get displayLabel {
    switch (this) {
      case PlaylistTag.pop:
        return 'Pop';
      case PlaylistTag.hipHop:
        return 'Hip Hop';
      case PlaylistTag.rnb:
        return 'R&B';
      case PlaylistTag.rock:
        return 'Rock';
      case PlaylistTag.jazz:
        return 'Jazz';
      case PlaylistTag.classical:
        return 'Classical';
      case PlaylistTag.electronic:
        return 'Electronic';
      case PlaylistTag.country:
        return 'Country';
      case PlaylistTag.chill:
        return 'Chill';
      case PlaylistTag.workout:
        return 'Workout';
      case PlaylistTag.party:
        return 'Party';
      case PlaylistTag.focus:
        return 'Focus';
      case PlaylistTag.acoustic:
        return 'Acoustic';
    }
  }

  /// Parse a string value to PlaylistTag.
  static PlaylistTag? fromValue(String value) {
    final upperValue = value.toUpperCase();
    for (final tag in PlaylistTag.values) {
      if (tag.value == upperValue) {
        return tag;
      }
    }
    return null;
  }

  /// Get all available tags.
  static List<PlaylistTag> get all => PlaylistTag.values;
}
