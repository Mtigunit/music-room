import 'dart:async';

import 'package:flutter/material.dart';
import 'package:music_room/core/widgets/skeleton_box.dart';

class PlaylistDetailsSkeleton extends StatefulWidget {
  const PlaylistDetailsSkeleton({super.key});

  @override
  State<PlaylistDetailsSkeleton> createState() =>
      _PlaylistDetailsSkeletonState();
}

class _PlaylistDetailsSkeletonState extends State<PlaylistDetailsSkeleton>
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final safeAreaTop = MediaQuery.paddingOf(context).top;
    final heroHeight = (MediaQuery.sizeOf(context).width * 0.56).clamp(
      180.0,
      250.0,
    );

    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: heroHeight + safeAreaTop,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: colorScheme.surfaceContainer,
                      child: const SizedBox.expand(),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: (heroHeight + safeAreaTop) * 0.38,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              colorScheme.surface.withValues(alpha: 0),
                              colorScheme.surface.withValues(alpha: 0.24),
                              colorScheme.surface,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: SkeletonBox(
                        animation: _controller,
                        width: 72,
                        height: 72,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(
                      animation: _controller,
                      height: 28,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    const SizedBox(height: 8),
                    SkeletonBox(
                      animation: _controller,
                      width: 160,
                      height: 18,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: List.generate(
                        4,
                        (_) => SkeletonBox(
                          animation: _controller,
                          width: 74,
                          height: 28,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SkeletonBox(
                      animation: _controller,
                      height: 16,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    const SizedBox(height: 8),
                    SkeletonBox(
                      animation: _controller,
                      width: 220,
                      height: 16,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    const SizedBox(height: 16),
                    SkeletonBox(
                      animation: _controller,
                      height: 54,
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          sliver: SliverToBoxAdapter(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SkeletonBox(
                  animation: _controller,
                  width: 90,
                  height: 24,
                  borderRadius: BorderRadius.circular(10),
                ),
                SkeletonBox(
                  animation: _controller,
                  width: 110,
                  height: 16,
                  borderRadius: BorderRadius.circular(10),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return Padding(
                  padding: EdgeInsets.only(bottom: index == 4 ? 0 : 12),
                  child: _TrackTileSkeleton(animation: _controller),
                );
              },
              childCount: 5,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrackTileSkeleton extends StatelessWidget {
  const _TrackTileSkeleton({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.18),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          SkeletonBox(
            animation: animation,
            width: 58,
            height: 58,
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
                const SizedBox(height: 8),
                SkeletonBox(
                  animation: animation,
                  width: 140,
                  height: 14,
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SkeletonBox(
                animation: animation,
                width: 44,
                height: 14,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 10),
              SkeletonBox(
                animation: animation,
                width: 22,
                height: 22,
                borderRadius: BorderRadius.circular(20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
