import 'package:music_room/core/models/tag_option.dart';
import 'package:music_room/core/utils/tag_registry.dart';

final class AppTags {
  const AppTags._();

  static const TagOption<String> pop = TagOption<String>(
    value: 'POP',
    label: 'Pop',
  );
  static const TagOption<String> hipHop = TagOption<String>(
    value: 'HIP_HOP',
    label: 'Hip Hop',
  );
  static const TagOption<String> rnb = TagOption<String>(
    value: 'RNB',
    label: 'R&B',
  );
  static const TagOption<String> rock = TagOption<String>(
    value: 'ROCK',
    label: 'Rock',
  );
  static const TagOption<String> jazz = TagOption<String>(
    value: 'JAZZ',
    label: 'Jazz',
  );
  static const TagOption<String> classical = TagOption<String>(
    value: 'CLASSICAL',
    label: 'Classical',
  );
  static const TagOption<String> electronic = TagOption<String>(
    value: 'ELECTRONIC',
    label: 'Electronic',
  );
  static const TagOption<String> country = TagOption<String>(
    value: 'COUNTRY',
    label: 'Country',
  );
  static const TagOption<String> chill = TagOption<String>(
    value: 'CHILL',
    label: 'Chill',
  );
  static const TagOption<String> workout = TagOption<String>(
    value: 'WORKOUT',
    label: 'Workout',
  );
  static const TagOption<String> party = TagOption<String>(
    value: 'PARTY',
    label: 'Party',
  );
  static const TagOption<String> focus = TagOption<String>(
    value: 'FOCUS',
    label: 'Focus',
  );
  static const TagOption<String> acoustic = TagOption<String>(
    value: 'ACOUSTIC',
    label: 'Acoustic',
  );

  static const List<TagOption<String>> values = <TagOption<String>>[
    pop,
    hipHop,
    rnb,
    rock,
    jazz,
    classical,
    electronic,
    country,
    chill,
    workout,
    party,
    focus,
    acoustic,
  ];

  static const TagRegistry<String> registry = TagRegistry<String>(values);
}
