import 'dart:async';

import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/skeleton_box.dart';
import 'package:music_room/features/search/data/models/search_filter_type.dart';

class SearchResultsSkeleton extends StatefulWidget {
  const SearchResultsSkeleton({
    required this.filter,
    super.key,
  });

  final SearchFilterType filter;

  @override
  State<SearchResultsSkeleton> createState() => _SearchResultsSkeletonState();
}

class _SearchResultsSkeletonState extends State<SearchResultsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    unawaited(
      (_controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )).repeat(reverse: true),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 720;
    final padding = EdgeInsets.fromLTRB(
      isWide ? 28 : 20,
      4,
      isWide ? 28 : 20,
      20,
    );

    return ListView.separated(
      padding: padding,
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        switch (widget.filter) {
          case SearchFilterType.tracks:
            return _TrackSkeleton(animation: _controller);
          case SearchFilterType.users:
            return _UserSkeleton(animation: _controller);
          case SearchFilterType.events:
            return _EventSkeleton(animation: _controller);
          case SearchFilterType.playlists:
            return _PlaylistSkeleton(animation: _controller);
        }
      },
    );
  }
}

class _TrackSkeleton extends StatelessWidget {
  const _TrackSkeleton({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SkeletonBox(
            animation: animation,
            width: 64,
            height: 64,
            borderRadius: BorderRadius.circular(14),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(
                  animation: animation,
                  height: 16,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 6),
                SkeletonBox(
                  animation: animation,
                  width: 140,
                  height: 14,
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SkeletonBox(
            animation: animation,
            width: 48,
            height: 48,
            borderRadius: BorderRadius.circular(16),
          ),
        ],
      ),
    );
  }
}

class _UserSkeleton extends StatelessWidget {
  const _UserSkeleton({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(
            animation: animation,
            width: 60,
            height: 60,
            shape: BoxShape.circle,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SkeletonBox(
                        animation: animation,
                        height: 16,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SkeletonBox(
                      animation: animation,
                      width: 74,
                      height: 24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SkeletonBox(
                  animation: animation,
                  height: 14,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 6),
                SkeletonBox(
                  animation: animation,
                  width: 180,
                  height: 14,
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventSkeleton extends StatelessWidget {
  const _EventSkeleton({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(
            animation: animation,
            width: 72,
            height: 72,
            borderRadius: BorderRadius.circular(14),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SkeletonBox(
                        animation: animation,
                        height: 16,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SkeletonBox(
                      animation: animation,
                      width: 60,
                      height: 24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SkeletonBox(
                  animation: animation,
                  height: 14,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 6),
                SkeletonBox(
                  animation: animation,
                  width: 180,
                  height: 14,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SkeletonBox(
                      animation: animation,
                      width: 84,
                      height: 22,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    SkeletonBox(
                      animation: animation,
                      width: 72,
                      height: 22,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistSkeleton extends StatelessWidget {
  const _PlaylistSkeleton({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(
            animation: animation,
            width: 72,
            height: 72,
            borderRadius: BorderRadius.circular(14),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SkeletonBox(
                        animation: animation,
                        height: 16,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SkeletonBox(
                      animation: animation,
                      width: 64,
                      height: 24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SkeletonBox(
                  animation: animation,
                  height: 14,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SkeletonBox(
                      animation: animation,
                      width: 68,
                      height: 22,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    SkeletonBox(
                      animation: animation,
                      width: 82,
                      height: 22,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
