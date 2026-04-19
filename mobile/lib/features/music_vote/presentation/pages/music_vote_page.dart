import 'package:flutter/material.dart';
import 'package:music_room/features/music_vote/presentation/widgets/music_vote_view.dart';

/// Entry-point page for the "Live Event / Music Track Vote" feature.
///
/// Wraps [MusicVoteView] inside a [SafeArea]-bounded [Scaffold].
/// This page is the tab-level widget mounted inside the app scaffold.
class MusicVotePage extends StatelessWidget {
  const MusicVotePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: MusicVoteView(),
      ),
    );
  }
}
