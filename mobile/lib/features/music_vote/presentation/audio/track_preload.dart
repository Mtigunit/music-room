import 'package:music_room/features/music_vote/presentation/audio/room_audio_player.dart';
import 'package:music_room/features/music_vote/presentation/state/music_vote_cubit.dart';

/// Preloads [providerTrackId] when needed before emitting play/next.
///
/// Returns `false` when preload was required but failed, or when [isMounted]
/// is false after the await. Returns `true` when the track is already loaded,
/// when [preload] is false, or when preload succeeds.
Future<bool> ensureTrackPreloaded({
  required RoomAudioPlayer player,
  required MusicVoteCubit cubit,
  required String providerTrackId,
  required int startPositionMs,
  required bool Function() isMounted,
  bool preload = true,
}) async {
  if (!preload || player.loadedProviderTrackId == providerTrackId) {
    return true;
  }

  cubit.setAudioLoading(isLoading: true);
  final loaded = await player.loadTrack(
    providerTrackId,
    startPositionMs,
    autoPlay: false,
  );
  if (!isMounted()) return false;
  if (!loaded) {
    cubit.setAudioLoading(isLoading: false);
  }
  return loaded;
}
