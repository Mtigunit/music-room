import 'package:music_room/features/music_vote/presentation/state/music_vote_event.dart';
import 'package:music_room/features/music_vote/presentation/state/music_vote_state.dart';

class MusicVoteBloc {
  MusicVoteState state = MusicVoteInitial();

  void add(MusicVoteEvent event) {}
}
