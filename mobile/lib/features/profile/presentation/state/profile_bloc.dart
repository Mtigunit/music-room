import 'package:music_room/features/profile/presentation/state/profile_event.dart';
import 'package:music_room/features/profile/presentation/state/profile_state.dart';

class ProfileBloc {
  ProfileState state = ProfileInitial();

  void add(ProfileEvent event) {}
}
