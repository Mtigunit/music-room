import 'package:music_room/features/auth/presentation/state/auth_event.dart';
import 'package:music_room/features/auth/presentation/state/auth_state.dart';

class AuthBloc {
  AuthState state = AuthInitial();

  void add(AuthEvent event) {}
}
