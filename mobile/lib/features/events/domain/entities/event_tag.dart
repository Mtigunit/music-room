enum EventTag {
  pop('POP', 'Pop'),
  hipHop('HIP_HOP', 'Hip Hop'),
  rnb('RNB', 'R&B'),
  rock('ROCK', 'Rock'),
  jazz('JAZZ', 'Jazz'),
  classical('CLASSICAL', 'Classical'),
  electronic('ELECTRONIC', 'Electronic'),
  country('COUNTRY', 'Country'),
  chill('CHILL', 'Chill'),
  workout('WORKOUT', 'Workout'),
  party('PARTY', 'Party'),
  focus('FOCUS', 'Focus'),
  acoustic('ACOUSTIC', 'Acoustic')
  ;

  const EventTag(this.backendValue, this.label);

  final String backendValue;
  final String label;
}
