import 'package:flutter/material.dart';
import 'package:music_room/features/home/presentation/widgets/genre_filter_list.dart';
import 'package:music_room/features/home/presentation/widgets/home_header.dart';
import 'package:music_room/features/home/presentation/widgets/home_search_bar.dart';
import 'package:music_room/features/home/presentation/widgets/room_vertical_card.dart';
import 'package:music_room/features/home/presentation/widgets/section_title.dart';
import 'package:music_room/features/home/presentation/widgets/trending_room_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HomeHeader(),
                const SizedBox(height: 24),
                const HomeSearchBar(),
                const SizedBox(height: 24),
                const GenreFilterList(),
                const SizedBox(height: 32),

                SectionTitle(
                  title: 'Active Near You',
                  subtitle: 'Based on your location',
                  onSeeAllPressed: () {},
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 320,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    itemCount: 3,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      return const RoomVerticalCard(
                        width: 280,
                        roomTitle: 'Late Night Vibes',
                        hostName: 'djnova',
                        trackName: 'Midnight City',
                        artistName: 'M83',
                        listenerCount: 247,
                        genre: 'ELECTRONIC',
                        imageAsset: 'assets/images/step1.webp',
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),

                SectionTitle(
                  title: 'Trending Now',
                  subtitle: 'Most active rooms globally',
                  onSeeAllPressed: () {},
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 160,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    itemCount: 4,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      return const TrendingRoomCard(
                        roomTitle: 'Chill Sunday Session',
                        listenerCount: 89,
                        imageAsset: 'assets/images/step2.webp',
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),

                SectionTitle(
                  title: "Friends' Rooms",
                  subtitle: 'People you follow are listening',
                  onSeeAllPressed: () {},
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 320,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    itemCount: 3,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      return const RoomVerticalCard(
                        width: 280,
                        roomTitle: "Alex's Playlist",
                        hostName: 'alex_m',
                        trackName: 'Blinding Lights',
                        artistName: 'The Weeknd',
                        listenerCount: 12,
                        genre: 'MIXED',
                        imageAsset: 'assets/images/step3.webp',
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 16,
            right: 24,
            child: FloatingActionButton.extended(
              onPressed: null,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              icon: const Icon(Icons.add),
              label: const Text(
                'Create Room',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
