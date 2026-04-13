import 'package:music_room/features/music_control/presentation/state/music_control_event.dart';
import 'package:music_room/features/music_control/presentation/state/music_control_state.dart';

class MusicControlBloc {
  MusicControlState state = MusicControlInitial();

  void add(MusicControlEvent event) {}
}
